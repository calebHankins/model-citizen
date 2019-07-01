FROM perl
RUN cpanm --notest Log::Log4perl && cpanm --notest Module::Build
RUN cpanm --notest JSON && cpanm --notest XML::Twig
COPY . /usr/src/model-citizen
WORKDIR /usr/src/model-citizen
RUN cpanm --verbose .
ENTRYPOINT [ "model-citizen" ]
LABEL name=model-citizen maintainer="Caleb Hankins <caleb.hankins@acxiom.com>"
