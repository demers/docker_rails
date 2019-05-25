FROM ubuntu:18.04

MAINTAINER FND <fndemers@gmail.com>

ENV TERM=xterm\
    TZ=America/Toronto\
    DEBIAN_FRONTEND=noninteractive

ENV PROJECTNAME=RAILS

ENV WORKDIRECTORY=/home/ubuntu

ENV RAILS_VERSION 5.2.2
ENV RUBY_VERSION 2.6.1

# Access SSH login
ENV USERNAME=ubuntu
ENV PASSWORD=ubuntu

RUN apt-get update

RUN apt-get install -y apt-utils vim-nox curl git exuberant-ctags

# Install a basic SSH server
RUN apt install -y openssh-server
RUN sed -i 's|session    required     pam_loginuid.so|session    optional     pam_loginuid.so|g' /etc/pam.d/sshd
RUN mkdir -p /var/run/sshd
RUN /usr/bin/ssh-keygen -A

# Install Java
RUN apt-get install -qy --no-install-recommends python-dev default-jdk

# Add user to the image
RUN adduser --quiet --disabled-password --shell /bin/bash --home /home/${USERNAME} --gecos "User" ${USERNAME}
# Set password for the jenkins user (you may want to alter this).
RUN echo "$USERNAME:$PASSWORD" | chpasswd

RUN apt-get clean && apt-get -y update && apt-get install -y locales && locale-gen fr_CA.UTF-8
ENV TZ=America/Toronto
#RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
#RUN /usr/bin/timedatectl set-timezone $TZ
RUN unlink /etc/localtime
RUN ln -s /usr/share/zoneinfo/$TZ /etc/localtime


RUN apt install -y fish

RUN echo "export PS1=\"\\e[0;31m $PROJECTNAME\\e[m \$PS1\"" >> ${WORKDIRECTORY}/.bash_profile

# Install all you want here...


# Standard SSH port
EXPOSE 22

# Installation X11.
RUN apt install -y xauth vim-gtk

# Installation de FZF.
RUN apt install -y silversearcher-ag

RUN apt-get install -y build-essential cmake python3-dev

RUN cd ${WORKDIRECTORY} \
    && git clone git://github.com/zaiste/vimified.git \
    && ln -sfn vimified/ ${WORKDIRECTORY}/.vim \
    && ln -sfn vimified/vimrc ${WORKDIRECTORY}/.vimrc \
    && cd vimified \
    && mkdir bundle \
    && mkdir -p tmp/backup tmp/swap tmp/undo \
    && git clone https://github.com/gmarik/vundle.git bundle/vundle \
    && echo "let g:vimified_packages = ['general', 'coding', 'fancy', 'indent', 'css', 'os', 'ruby', 'js', 'haskell', 'python', 'color']" > local.vimrc

COPY after.vimrc ${WORKDIRECTORY}/vimified/

COPY extra.vimrc ${WORKDIRECTORY}/vimified

# Générer les tags de ctags.
RUN echo "ctags -f ${WORKDIRECTORY}/mytags -R ${WORKDIRECTORY}" >> ${WORKDIRECTORY}/.bash_profile

# Compiling YouCompleteMe only once...
RUN echo "if ! [ -f ~/.runonce_install ]; then" >> ${WORKDIRECTORY}/.bash_profile
RUN echo "touch ~/.runonce_install" >> ${WORKDIRECTORY}/.bash_profile
RUN echo "vim +BundleInstall +qall" >> ${WORKDIRECTORY}/.bash_profile
RUN echo "cd ~/.vim/bundle/YouCompleteMe" >> ${WORKDIRECTORY}/.bash_profile
RUN echo "./install.py --clang-completer" >> ${WORKDIRECTORY}/.bash_profile
RUN echo "fi" >> ${WORKDIRECTORY}/.bash_profile
RUN echo "cd ~/" >> ${WORKDIRECTORY}/.bash_profile

# Replace shell with bash so we can source files
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

RUN cd ${WORKDIRECTORY} \
    && mkdir work \
&& chown -R $USERNAME:$PASSWORD work vimified .vim .vimrc .bash_profile


RUN apt -qy install curl g++ gcc autoconf automake bison libc6-dev libffi-dev libgdbm-dev libncurses5-dev libsqlite3-dev libtool libyaml-dev make pkg-config sqlite3 zlib1g-dev libgmp-dev libreadline-dev libssl-dev

RUN apt -qy install gnupg2

#RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
#RUN curl -sSL https://get.rvm.io | bash -s stable

#RUN /bin/bash -l -c ". /etc/profile.d/rvm.sh && rvm install $RUBY_VERSION"
#RUN echo "/etc/profile.d/rvm.sh" >> ${WORKDIRECTORY}/.bash_profile

RUN apt -qy install ruby ruby-dev

# Installer nodejs
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash -s stable
#RUN curl -sL https://deb.nodesource.com/setup_8.x | bash -s stable

RUN apt-get install -y nodejs

RUN gem update --system
RUN gem -v

# Install Rails
RUN gem install rails -v $RAILS_VERSION

RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
RUN apt -qy install wget ca-certificates
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN apt update
#RUN apt -qy install postgresql-10 pgadmin4
#RUN sh -c "echo 'deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
#RUN wget --quiet -O - http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add -
#RUN apt-get update

#RUN apt-get -qy install postgresql-common
#RUN apt-get -qy install postgresql-9.5 libpq-dev #pgadmin4

RUN apt install -qy postgresql postgresql-contrib

#RUN update-rc.d postgresql enable
#RUN service postgresql start

#RUN apt-get install -y mysql-server mysql-client libmysqlclient-dev

EXPOSE 3000

# Création d'un projet Rails de test
ENV APP_HOME /app
RUN mkdir $APP_HOME

RUN cd $APP_HOME && \
    rails new myapp -d postgresql && \
    find .

RUN cd $APP_HOME/myapp/ && \
    rake db:create

# Start SSHD server...
CMD ["/usr/sbin/sshd", "-D"]