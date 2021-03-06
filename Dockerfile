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

USER root
RUN mkdir /opt/clasp
RUN chown -R ${APP_USER} /opt/clasp

USER ${APP_USER}
RUN echo "fu"
RUN git clone https://github.com/clasp-developers/clasp.git
WORKDIR ${HOME}/clasp/extensions
RUN git clone https://github.com/cando-developers/cando.git

WORKDIR ${HOME}/clasp
RUN echo "PREFIX = '/opt/clasp'" > wscript.config && \
    echo "USE_PARALLEL_BUILD = True" >> wscript.config && \
    echo "USE_LLD = True" >> wscript.config && \
    echo "CLASP_BUILD_MODE = \"faso\"" >> wscript.config && \
    sed -i s/"--link-static",//g wscript && \
    ./waf configure && ./waf build_cboehm
#RUN git clone https://github.com/cando-developers/cando.git extensions/cando

USER root
RUN apt-get install -y libnetcdf-dev

USER ${APP_USER}
WORKDIR ${HOME}/quicklisp/local-projects
RUN git clone https://github.com/sionescu/bordeaux-threads.git
RUN git clone https://github.com/clasp-developers/uuid.git
RUN git clone https://github.com/clasp-developers/cl-netcdf.git

COPY --chown=${APP_UID}:${APP_USER} home ${HOME}

USER ${APP_USER}
WORKDIR ${HOME}/clasp
RUN ./waf install_cboehm ; exit 0

USER ${APP_USER}
WORKDIR ${HOME}

RUN pip3 install --user jupyter jupyterlab jupyter_kernel_test && \
    jupyter serverextension enable --user --py jupyterlab && \
    jupyter labextension install @jupyter-widgets/jupyterlab-manager && \
    jupyter nbextension enable --user --py widgetsnbextension

RUN echo "bar"
RUN git clone -b clasp-updates https://github.com/yitzchak/common-lisp-jupyter.git ${HOME}/quicklisp/local-projects/common-lisp-jupyter

RUN sbcl --eval "(ql:quickload '(:common-lisp-jupyter))" --eval "(cl-jupyter:install :use-implementation t)" --quit
RUN /opt/clasp/bin/iclasp-boehm --eval "(ql:quickload '(:common-lisp-jupyter))" --eval "(cl-jupyter:install :use-implementation t)" --quit

WORKDIR /opt/clasp
RUN git clone https://github.com/slime/slime.git

ENV SLIME_HOME "/opt/clasp/slime"
RUN /opt/clasp/bin/iclasp-boehm -N \
    -e '(load (format nil "/opt/clasp/slime/swank-loader.lisp"))' \
    -e '(setq swank-loader::*fasl-directory* "/opt/clasp/slime/fasl/")' \
    -e "(swank-loader:init :delete nil :reload nil :load-contribs nil)" \
    -e "(core:quit)" 

CMD jupyter-lab --ip=0.0.0.0
