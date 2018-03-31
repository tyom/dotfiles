FROM ubuntu

RUN apt-get update -qq
RUN apt-get upgrade -y
RUN apt-get install -y build-essential curl vim git ruby

COPY . /root/dotfiles
WORKDIR /root/dotfiles

RUN ./setup.sh -y