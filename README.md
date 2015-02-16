# cnpqwsproxy

OpenResty-based SOAP caching proxy for CNPq / Lattes Platform WebServices.
[\[**Português**\]](README.pt_BR.md)

## Introduction

The [Lattes Platform](http://lattes.cnpq.br) is a government-maintained public database containing Brazilian researchers curricula, which can be accessed by anyone using a web browser. Raw curriculum metadata in XML format can also be obtained, but its automated download (without a CAPTCHA) is only officially permitted through a [SOAP webservice](http://www.cnpq.br/web/portal-lattes/extracoes-de-dados), which is made available only to Brazilian research and higher education institutions. However, each institution can request access rights only for a single IP address. Thus, this proxy has the following goals:

* To allow the institution to manage its own internal list of IP addresses which are allowed to access the webservice.

* To ensure multiple applications from the same institution accessing the webservice will not cause a significant overhead on CNPq servers, by caching responses whenever possible.

* To preserve compatibility with any existing applications. Replacing the webservice address in the WSDL file or overriding DNS response using `/etc/hosts` should be enough to cause an application to use the proxy.

This project also aims to serve as a good example on how to create smart SOAP caches. Aside from some specific configurations (`conf/`) and from specific hooks (`wscallhooks`) in `scripts/cnpqws_cache_key.lua`, the code should be pretty generic and adaptable for caching other SOAP webservices.

## Installing OpenResty

[OpenResty](http://openresty.org) is a platform build around [nginx](http://nginx.org), [LuaJIT](http://luajit.org), and some extension modules, on the top of which our proxy was developed.

Please follow these instructions to build and install OpenResty:

* [Download](http://openresty.org/#Download) the latest OpenResty release.

* Unpack it:

  `tar -zxvf ngx_openresty-*.tar.gz`

* Apply our patch to workaround issues (RFC2818 non-compliance) with the certificate currently used by `servicosweb.cnpq.br`:

  `cd ngx_openresty-*`
  
  `patch -p1 -i ../cnpqwsproxy/patches/openresty-*_x509_check_flag_always_check_subject.diff`

* Compile and install it:

  `./configure --with-pcre-jit --with-ipv6`

  `make && sudo make install`

* Add the OpenResty installation directory to your PATH. For example, append this line to the end of your `~/.bashrc` file:

  `export PATH=/usr/local/openresty/nginx/sbin:$PATH`

## Installing cnpqwsproxy

* Generate a private key and the corresponding certificate for the embedded TLS server. Edit the Makefile to change the certificate information provided to openssl through the `-subj` option. Then call:

  `make conf/tls/private/cnpqwsproxy.crt`

* Edit `conf/proxyconf.lua`. The `wsdl.replacewith` option contains an URL whose domain should be changed to your institution's domain.

  If desired, also customize any caching times in this file. Please note that although curricula are cached for 6 months by default, the `mtimehook` defined in `scripts/cnpqws_cache_key.lua` implies that the modification time will always be looked up to check whether a new version of a curriculum is available. The modification time is cached, by default, only for 15 minutes.

* Add the IP address ranges which are allowed to access the proxy to the `conf/cnpqws_allowed_clients.conf` file. By default, the proxy only allows requests from localhost.

* Start the proxy application:

  `./app start`

## Testing

### Python SUDS

* Install ipython and SUDS:

  `sudo apt-get install ipython python-suds`

* Call `ipython` and try some webservice calls:

   ```python
   In [1]: import suds
   In [2]: c = suds.client.Client('https://your-domain:7443/srvcurriculo/WSCurriculo?wsdl')
   In [3]: c.service.getDataAtualizacaoCV(id='9110045494449064')  # in memoriam
   Out[3]: 27/05/2004 11:39:54
   ```

### Apache CXF

* Install Maven.

  `sudo apt-get install maven`

* Clone the [cxf-repl](https://github.com/nitmateriais/cxf-repl) project:

  `git clone https://github.com/nitmateriais/cxf-repl.git`

* Compile and call the REPL:

  `cd cxf-repl`

  `make repl`

* Try some webservice calls:

  ```python
  >>> import br.cnpq.repositorio.servico.ws.WSCurriculo_Service as WSCurriculo_Service
  >>> service = WSCurriculo_Service()
  >>> port = service.WSCurriculoPort
  >>> port.getDataAtualizacaoCV('9110045494449064')  # in memoriam
  u'27/05/2004 11:39:54'
  ```
