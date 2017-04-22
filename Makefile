TLS_CERT_SUBJ ?= /CN=cnpqwsproxy.ufscar.br/O=FUNDACAO UNIVERSIDADE FEDERAL DE SAO CARLOS/OU=/L=Sao Carlos/ST=SP/C=BR

all:
	@echo "make all is not available"
	@echo "please read the Makefile to see the available targets"
	@exit 1

conf/tls/serpro_final_ssl.pem:
	for url in \
		https://repositorio.serpro.gov.br/docs/icpbrasilv5.crt \
		https://repositorio.serpro.gov.br/docs/acserprov4.crt \
		https://acraiz.icpbrasil.gov.br/credenciadas/SERPRO/v5/Autoridade_Certificadora_do_Serpro_Final_SSL.crt; \
		do \
			curl -k $$url | openssl x509 -text | sed -n 's,^[[:space:]]*,,;/^\(Issuer\|Subject\):/p'; \
			curl -k $$url; \
			echo; \
		done > "$@"

tls-conf: conf/tls/private/cnpqwsproxy.crt conf/tls/dh2048.pem

conf/tls/private/cnpqwsproxy.crt: conf/tls/private/cnpqwsproxy.key
	B=$(basename $@) ; \
	openssl req -new -key "$$B.key" -out "$$B.csr" -subj "$(TLS_CERT_SUBJ)" ; \
	openssl req -x509 -sha256 -days 3650 -key "$$B.key" -in "$$B.csr" -out "$@"
conf/tls/private/cnpqwsproxy.key:
	umask 377 ; \
	openssl genrsa -des3 -out "$@.orig" -passout pass:1234 4096 ; \
	openssl rsa -in "$@.orig" -out "$@" -passin pass:1234 ; \
	rm -f "$@.orig"

conf/tls/dh2048.pem:
	openssl dhparam -out "$@" 2048
