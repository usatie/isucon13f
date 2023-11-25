include $(HOME)/env

# Environment Variables
# SERVER_ID: defined in env

# 使用する前に変更すべき設定値
USER:=isucon
BIN_NAME:=isupipe
BUILD_DIR:=$(HOME)/webapp/go
SERVICE_NAME:=$(BIN_NAME)-go.service
GO_DIR:=$(HOME)/local/go
NODE_DIR:=$(HOME)/local/node
ENV_NAME:=env
MYSQL_NET:=$(ISUCON13_MYSQL_DIALCONFIG_NET)
MYSQL_HOST:=$(ISUCON13_MYSQL_DIALCONFIG_ADDRESS)
MYSQL_PORT:=$(ISUCON13_MYSQL_DIALCONFIG_PORT)
MYSQL_USER:=$(ISUCON13_MYSQL_DIALCONFIG_USER)
MYSQL_PASS:=$(ISUCON13_MYSQL_DIALCONFIG_PASSWORD)
MYSQL_DBNAME:=$(ISUCON13_MYSQL_DIALCONFIG_DATABASE)
MYSQL_PARSETIME:=$(ISUCON13_MYSQL_DIALCONFIG_PARSETIME)

# Configurable (but unnecessary to change)
GITHUB_USER:=usatie
GITHUB_REPO:=usatie/isucon13f
GITHUB_ADDKEY_URL:=https://github.com/$(GITHUB_REPO)/settings/keys/new
GITHUB_REPO_URL:=git@github.com:$(GITHUB_REPO).git

# paths should be abosolute path
DB_PATH:=/etc/mysql
NGINX_PATH:=/etc/nginx
SYSTEMD_PATH:=/etc/systemd
ENVSH_PATH:=$(HOME)/$(ENV_NAME)
DB_DIR_PATH:=/etc
NGINX_DIR_PATH:=/etc
SYSTEMD_DIR_PATH:=/etc
ENVSH_DIR_PATH:=$(HOME)

GITIGNORE_PATH:=$(HOME)/.gitignore
ZSHRC_PATH:=$(HOME)/.zshrc
BASHRC_PATH:=$(HOME)/.bashrc
VIMRC_PATH:=$(HOME)/.vimrc

NGINX_LOG:=/var/log/nginx/access.log
NGINX_ERROR_LOG:=/var/log/nginx/error.log
DB_SLOW_LOG:=/var/log/mysql/mysql-slow.log
DB_ERROR_LOG:=/var/log/mysql/error.log

ALP_CONFIG_DIR:=$(HOME)/tool-config/alp
ALP_CONFIG:=$(ALP_CONFIG_DIR)/config.yml
TRDSQL_DIR:=$(HOME)/tool-config/trdsql
TRDSQL_SQL:=$(TRDSQL_DIR)/access.sql

DURATION=120
RESULT_DIR:=$(HOME)/results

# Main commands
.PHONY: setup
setup: addkey vim-setup git-setup install-tools makedir keygen

.PHONY: get-conf
get-conf: check-server-id get-db-conf get-nginx-conf get-service-file get-envsh

.PHONY: deploy-conf
deploy-conf: check-server-id deploy-db-conf deploy-nginx-conf deploy-service-file deploy-envsh

PHONY: bench-result-dir
bench-result-dir: $(RESULT_DIR)
	$(eval n := $(shell (ls -l $(RESULT_DIR) || echo 1) | wc -l))
	mkdir -p $(RESULT_DIR)/$(n)

.PHONY: bench
bench: check-server-id rotate build deploy-conf restart bench-result-dir
	# Stats
	$(MAKE) top &
	$(MAKE) dstat &
	$(MAKE) pprof-record &
	
	# App log
	@$(MAKE) app-log

.PHONY: bench-db
bench-db: check-server-id rotate deploy-conf restart bench-result-dir
	# Stats
	$(MAKE) top &
	$(MAKE) dstat &

.PHONY: top
top: $(RESULT_DIR)
	$(eval n := $(shell (ls -l $(RESULT_DIR) || echo 1) | tail +2 | wc -l))
	LINES=20 top -b -d 1 -n $(DURATION) -w > $(RESULT_DIR)/$(n)/top.$(SERVER_ID).log

.PHONY: dstat
dstat: $(RESULT_DIR)
	$(eval n := $(shell (ls -l $(RESULT_DIR) || echo 1) | tail +2 | wc -l))
	dstat -tcdm --tcp -n 1 $(DURATION) > $(RESULT_DIR)/$(n)/dstat.$(SERVER_ID).log

.PHONY: app-log
app-log:
	sudo journalctl -f -u $(SERVICE_NAME)

$(RESULT_DIR):
	@mkdir -p $(RESULT_DIR)

.PHONY: slow-query
slow-query: $(RESULT_DIR)
	$(eval n := $(shell (ls -l $(RESULT_DIR) || echo 1) | tail +2 | wc -l))
	sudo pt-query-digest --explain h=$(MYSQL_HOST),u=$(MYSQL_USER),p=$(MYSQL_PASS) $(DB_SLOW_LOG) \
		| tee $(RESULT_DIR)/$(n)/slow-query.$(SERVER_ID).digest

.PHONY: alp
alp: $(RESULT_DIR)
	$(eval n := $(shell (ls -l $(RESULT_DIR) || echo 1) | tail +2 | wc -l))
	sudo alp ltsv --file=$(NGINX_LOG) --config=$(ALP_CONFIG) \
		| tee $(RESULT_DIR)/$(n)/alp.$(SERVER_ID).digest

.PHONY: pprof-record
pprof-record:
	go tool pprof -raw -seconds $(DURATION) http://localhost:6060/debug/pprof/profile

.PHONY: pprof-check
pprof-check:
	$(eval latest := $(shell ls -rt $(HOME)/pprof/ | tail -n 1))
	go tool pprof -http=localhost:8090 $(HOME)/pprof/$(latest)

.PHONY: access-db
access-db:
	mysql -h $(MYSQL_HOST) -P $(MYSQL_PORT) -u $(MYSQL_USER) -p$(MYSQL_PASS) $(MYSQL_DBNAME)

# Components
.PHONY: makedir
makedir:
	mkdir -p $(ALP_CONFIG_DIR)
	mkdir -p $(TRDSQL_DIR)
	mkdir -p $(RESULT_DIR)

.PHONY: keygen
keygen:
	ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa
	cat ~/.ssh/id_rsa.pub
	echo "Add this key to the repository $(GITHUB_ADDKEY_URL)"

.PHONY: install-tools
install-tools:
	# apt install
	sudo apt update
	sudo apt upgrade -y
	sudo apt install -y percona-toolkit dstat git unzip snapd graphviz tree net-tools iotop apache2-utils
	sudo add-apt-repository ppa:jonathonf/vim
	sudo apt install vim -y

	# alp
	wget https://github.com/tkuchiki/alp/releases/download/v1.0.9/alp_linux_amd64.zip \
		&& unzip alp_linux_amd64.zip \
		&& sudo install ./alp /usr/local/bin/alp \
		&& rm alp_linux_amd64.zip alp
	mkdir -p $(ALP_CONFIG_DIR)
	wget https://raw.githubusercontent.com/usatie/isucon-setup/main/tool-config/alp/config.yml -O $(ALP_CONFIG)
	# trdsql
	wget https://github.com/noborus/trdsql/releases/download/v0.10.0/trdsql_v0.10.0_linux_amd64.zip \
		&& unzip trdsql_v0.10.0_linux_amd64.zip \
		&& sudo install ./trdsql_v0.10.0_linux_amd64/trdsql /usr/local/bin/trdsql \
		&& rm -rf trdsql_v0.10.0_linux_amd64.zip trdsql_v0.10.0_linux_amd64
	mkdir -p $(TRDSQL_DIR)
	wget https://raw.githubusercontent.com/usatie/isucon-setup/main/tool-config/trdsql/access.sql -O $(TRDSQL_SQL)

.PHONYE: go-setup
go-setup:
	mkdir -p $(HOME)/local
	if [ -d $(GO_DIR) ]; then mv $(GO_DIR) $(GO_DIR)/go.orig; fi
	curl -L https://go.dev/dl/go1.18.3.linux-amd64.tar.gz | tar -zxf - -C $(HOME)/local
	# go (goimports/pprof)
	go install golang.org/x/tools/cmd/goimports@latest
	go install github.com/google/pprof@latest

.PHONYE: addkey
addkey:
	mkdir -p ~/.ssh
	curl https://github.com/$(GITHUB_USER).keys >> ~/.ssh/authorized_keys

.PHONY: git-setup
git-setup:
	git config --global user.email "isucon@example.com"
	git config --global user.name "isucon"
	@echo "# git-setup"
	@echo "/*" >> $(GITIGNORE_PATH)
	@echo "/$(ENV_NAME)" >> $(GITIGNORE_PATH)
	@echo "!$(BIN_NAME)" >> $(GITIGNORE_PATH)
	@echo "!webapp" >> $(GITIGNORE_PATH)
	@echo "!Makefile" >> $(GITIGNORE_PATH)
	@echo "!.gitignore" >> $(GITIGNORE_PATH)
	@echo "!results" >> $(GITIGNORE_PATH)
	@echo "!tool-config" >> $(GITIGNORE_PATH)
	@echo "!s1" >> $(GITIGNORE_PATH)
	@echo "!s2" >> $(GITIGNORE_PATH)
	@echo "!s3" >> $(GITIGNORE_PATH)
	@echo "!s4" >> $(GITIGNORE_PATH)
	@echo "!s5" >> $(GITIGNORE_PATH)
	@echo "# Common"
	@echo "$(BIN_NAME)" >> $(GITIGNORE_PATH)
	@echo "*.mount" >> $(GITIGNORE_PATH)
	@echo "*.swp" >> $(GITIGNORE_PATH)
	@echo "*.out" >> $(GITIGNORE_PATH)

.PHONY: oh-my-zsh
oh-my-zsh:
	sudo apt update
	sudo apt upgrade
	sudo apt install -y zsh
	sh -c "$$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

.PHONY: zsh-setup
zsh-setup:
	# zsh-autosuggestions
	git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
	@echo "# zsh-setup"
	@echo 'export VISUAL=vim' >> $(ZSHRC_PATH)
	@echo 'export EDITOR="$$VISUAL"' >> $(ZSHRC_PATH)
	@echo 'plugins+=(zsh-autosuggestions)' >> $(ZSHRC_PATH)
	@echo 'source $$ZSH/oh-my-zsh.sh' >> $(ZSHRC_PATH)
	@echo 'export PATH=$(NODE_DIR)/bin:$(GO_DIR)/bin:$$HOME/go/bin:$$PATH' >> $(ZSHRC_PATH)
	@echo 'export GOROOT=$(GO_DIR)' >> $(ZSHRC_PATH)
	@echo '# zsh-autosuggestions' >> $(ZSHRC_PATH)
	@echo 'bindkey '^o' autosuggest-accept' >> $(ZSHRC_PATH)
	@echo 'PROMPT=$(SERVER_ID):$$PROMPT' >> $(ZSHRC_PATH)
	@echo 'source env' >> $(ZSHRC_PATH)
	@echo 'alias gcm="git commit -m ' "'"'[$$SERVER_ID]'"'" '"'>> $(ZSHRC_PATH)
	@echo 'Restart zsh by "exec $$SHELL"'

.PHONY: vim-setup
vim-setup:
	@echo "# vim-setup"
	@echo 'set term=xterm-256color' >> $(VIMRC_PATH)
	@echo 'syntax on' >> $(VIMRC_PATH)
	@echo 'set tabstop=4' >> $(VIMRC_PATH)
	@echo 'set shiftwidth=4' >> $(VIMRC_PATH)
	@echo 'set autoindent' >> $(VIMRC_PATH)
	@echo 'set number' >> $(VIMRC_PATH)
	@echo "set viminfo='100,<200,s10,h" >> $(VIMRC_PATH)
	@echo "set shortmess-=S" >> $(VIMRC_PATH)
	@echo "" >> $(VIMRC_PATH)
	@echo 'call plug#begin()' >> $(VIMRC_PATH)
	@echo "  Plug 'prabirshrestha/vim-lsp'" >> $(VIMRC_PATH)
	@echo "  Plug 'mattn/vim-lsp-settings'" >> $(VIMRC_PATH)
	@echo "  Plug 'mattn/vim-goimports'" >> $(VIMRC_PATH)
	@echo "  Plug 'tpope/vim-unimpaired'" >> $(VIMRC_PATH)
	@echo 'call plug#end()' >> $(VIMRC_PATH)
	@echo '" Copilot Configurations' >> $(VIMRC_PATH)
	@echo "let g:copilot_filetypes = {'gitcommit': v:true, 'markdown': v:true, 'yaml': v:true, 'conf': v:true}" >> $(VIMRC_PATH)
	# vim-plug
	curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
		https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	vim +PlugInstall +qa
	git clone https://github.com/github/copilot.vim.git ~/.vim/pack/github/start/copilot.vim

.PHONY: check-server-id
check-server-id:
ifdef SERVER_ID
	@echo "SERVER_ID=$(SERVER_ID)"
else
	@echo "SERVER_ID is unset"
	@exit 1
endif

.PHONY: set-as-s1
set-as-s1:
	echo >> $(ENVSH_PATH)
	echo "SERVER_ID=s1" >> $(ENVSH_PATH)
	mkdir -p $(HOME)/s1

.PHONY: set-as-s2
set-as-s2:
	echo >> $(ENVSH_PATH)
	echo "SERVER_ID=s2" >> $(ENVSH_PATH)
	mkdir -p $(HOME)/s2

.PHONY: set-as-s3
set-as-s3:
	echo >> $(ENVSH_PATH)
	echo "SERVER_ID=s3" >> $(ENVSH_PATH)
	mkdir -p $(HOME)/s3

.PHONY: set-as-s4
set-as-s4:
	echo >> $(ENVSH_PATH)
	echo "SERVER_ID=s4" >> $(ENVSH_PATH)
	mkdir -p $(HOME)/s4

.PHONY: set-as-s5
set-as-s5:
	echo >> $(ENVSH_PATH)
	echo "SERVER_ID=s5" >> $(ENVSH_PATH)
	mkdir -p $(HOME)/s5

.PHONY: get-db-conf
get-db-conf:
	mkdir -p ~/$(SERVER_ID)$(DB_DIR_PATH)
	sudo rsync -qauh $(DB_PATH) ~/$(SERVER_ID)$(DB_DIR_PATH)
	sudo chown $(USER) -R ~/$(SERVER_ID)$(DB_DIR_PATH)

.PHONY: get-nginx-conf
get-nginx-conf:
	mkdir -p ~/$(SERVER_ID)$(NGINX_DIR_PATH)
	sudo rsync -qauh $(NGINX_PATH) ~/$(SERVER_ID)$(NGINX_DIR_PATH)
	sudo chown $(USER) -R ~/$(SERVER_ID)$(NGINX_DIR_PATH)

.PHONY: get-service-file
get-service-file:
	mkdir -p ~/$(SERVER_ID)$(SYSTEMD_DIR_PATH)
	sudo rsync -qauh $(SYSTEMD_PATH) ~/$(SERVER_ID)$(SYSTEMD_DIR_PATH)
	sudo chown $(USER) -R ~/$(SERVER_ID)$(SYSTEMD_DIR_PATH)

.PHONY: get-envsh
get-envsh:
	mkdir -p ~/$(SERVER_ID)$(ENVSH_DIR_PATH)
	rsync -qauh $(ENVSH_PATH) ~/$(SERVER_ID)$(ENVSH_DIR_PATH)

.PHONY: deploy-db-conf
deploy-db-conf:
	sudo rsync -qauh --no-o --no-g ~/$(SERVER_ID)$(DB_PATH) $(DB_DIR_PATH)

.PHONY: deploy-nginx-conf
deploy-nginx-conf:
	sudo rsync -qauh --no-o --no-g ~/$(SERVER_ID)$(NGINX_PATH) $(NGINX_DIR_PATH)

.PHONY: deploy-service-file
deploy-service-file:
	sudo rsync -qauh --no-o --no-g ~/$(SERVER_ID)$(SYSTEMD_PATH) $(SYSTEMD_DIR_PATH)

.PHONY: deploy-envsh
deploy-envsh:
	sudo rsync -qauh --no-o --no-g ~/$(SERVER_ID)$(ENVSH_PATH) $(ENVSH_DIR_PATH)

.PHONY: build
build:
	cd $(BUILD_DIR) && \
		go build -o $(BIN_NAME)

.PHONY: restart
restart:
	sudo systemctl daemon-reload
	sudo systemctl restart mysql
	sudo systemctl restart nginx
	sudo systemctl restart $(SERVICE_NAME)

.PHONY: rotate
rotate:
	sudo truncate $(NGINX_LOG) -s 0
	sudo truncate $(NGINX_ERROR_LOG) -s 0
	sudo truncate $(DB_SLOW_LOG) -s 0
	sudo truncate $(DB_ERROR_LOG) -s 0
	sudo nginx -s reopen
	sudo systemctl restart mysql

.PHONY: watch-service-log
watch-service-log:
	sudo journalctl -u $(SERVICE_NAME) -n10 -f
