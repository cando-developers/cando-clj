FROM debian:testing

ARG APP_USER=app
ARG APP_UID=1000

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -y update
RUN apt-get -y dist-upgrade
RUN apt-get -y install clang-9 curl git gpg libboost-date-time-dev \
    libboost-filesystem-dev libboost-graph-dev libboost-iostreams-dev \
    libboost-program-options-dev libboost-regex-dev libboost-system-dev \
    libbsd-dev libclang-9-dev libelf-dev libexpat-dev libgc-dev libgmp-dev \
    libzmq3-dev nano npm python3-pip sbcl wget zlib1g-dev

ENV CC "clang-9"
ENV CXX "clang++-9"

# RUN curl https://repo.anaconda.com/pkgs/misc/gpgkeys/anaconda.asc | gpg --dearmor > conda.gpg && \
#   install -o root -g root -m 644 conda.gpg /usr/share/keyrings/conda-archive-keyring.gpg && \
#   echo "deb [arch=amd64 signed-by=/usr/share/keyrings/conda-archive-keyring.gpg] https://repo.anaconda.com/pkgs/misc/debrepo/conda stable main" > /etc/apt/sources.list.d/conda.list
# RUN apt-get -y update
# RUN apt-get -y install conda

ENV USER ${APP_USER}
ENV HOME /home/${APP_USER}
ENV PATH "/opt/clasp/bin:$HOME/.local/bin:$PATH"

RUN useradd --create-home --shell=/bin/false --uid=${APP_UID} ${APP_USER}

WORKDIR ${HOME}
USER ${APP_USER}

RUN wget https://beta.quicklisp.org/quicklisp.lisp && \
    sbcl --load quicklisp.lisp --eval "(quicklisp-quickstart:install)" --quit && \
    rm quicklisp.lisp

RUN echo "wibble"
RUN git clone https://github.com/clasp-developers/clasp.git

WORKDIR ${HOME}/clasp
RUN echo "USE_PARALLEL_BUILD = True" > wscript.config && \
    echo "USE_LLD = True" >> wscript.config && \
    echo "CLASP_BUILD_MODE = \"faso\"" >> wscript.config && \
    sed -i s/"--link-static",//g wscript && \
    ./waf configure && ./waf build_cboehm
#RUN git clone https://github.com/cando-developers/cando.git extensions/cando

COPY --chown=${APP_UID}:${APP_USER} home ${HOME}

USER root
RUN ./waf install_cboehm

USER ${APP_USER}
WORKDIR ${HOME}

RUN pip3 install --user nglview==1.2.0 && \
  jupyter nbextension enable --py widgetsnbextension && \
  jupyter nbextension enable --py nglview

RUN git clone -b clasp-updates https://github.com/yitzchak/common-lisp-jupyter.git ${HOME}/quicklisp/local-projects/common-lisp-jupyter && \
    git clone https://github.com/clasp-developers/bordeaux-threads.git ${HOME}/quicklisp/local-projects/bordeaux-threads && \
    mkdir -p ${HOME}/quicklisp/local-projects/cl-nglview && \
    cd ${HOME}/quicklisp/local-projects/cl-nglview && \
    git init && \
    git remote add -f origin https://github.com/yitzchak/cl-nglview.git && \
    git config core.sparseCheckout true && \
    echo "cl-nglview/" >> .git/info/sparse-checkout && \
    git pull origin master && \
   git checkout clj-migrate

RUN sbcl --eval "(ql:quickload '(:common-lisp-jupyter :cl-nglview))" --eval "(cl-jupyter:install :use-implementation t)" --quit
#RUN iclasp-boehm --eval "(ql:quickload '(:common-lisp-jupyter :cl-nglview))" --quit --eval "(cl-jupyter:install :use-implementation t)" --quit

CMD jupyter-notebook --ip=0.0.0.0
