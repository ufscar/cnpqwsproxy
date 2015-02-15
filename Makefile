all:
	@echo "make all is not available"
	@echo "please read the Makefile to see the available targets"
	@exit 1

conf/tls/ICP-V2c.pem:
	curl -k https://www.downloadcertisign.com.br/site/Hierarquias/ICP_Brasil/hierarquia-completa/ICP-V2c.p7b | openssl pkcs7 -inform der -print_certs -out $@

conf/tls/private/cnpqwsproxy.crt: conf/tls/private/cnpqwsproxy.key
	B=$(basename $@) ; \
	openssl req -new -key "$$B.key" -out "$$B.csr" -subj "/CN=cnpqwsproxy.ufscar.br/O=FUNDACAO UNIVERSIDADE FEDERAL DE SAO CARLOS/OU=/L=Sao Carlos/ST=SP/C=BR" ; \
	openssl req -x509 -sha256 -days 3650 -key "$$B.key" -in "$$B.csr" -out "$@"
conf/tls/private/cnpqwsproxy.key:
	umask 377 ; \
	openssl genrsa -des3 -out "$@.orig" -passout pass:1234 4096 ; \
	openssl rsa -in "$@.orig" -out "$@" -passin pass:1234 ; \
	rm -f "$@.orig"
