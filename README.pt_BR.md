# cnpqwsproxy

Proxy cacheante baseado no OpenResty para os serviços web SOAP do CNPq / Plataforma Lattes.
[\[**English**\]](README.md)

## Introdução

A [Plataforma Lattes](http://lattes.cnpq.br) é um banco de dados público mantido pelo governo que contém os currículos de pesquisadores brasileiros, e que pode ser acessado por qualquer um por meio de um navegador web. Metadados brutos dos currículos em formato XML também podem ser obtidos, mas o download automatizado (sem CAPTCHA) desses dados só é permitido oficialmente por meio de um [serviço SOAP](http://www.cnpq.br/web/portal-lattes/extracoes-de-dados), que é disponibilizado somente para instituições brasileiras de pesquisa e ensino superior. No entanto, cada instituição só pode solicitar a liberação de acesso para um único endereço IP. Nesse contexto, este proxy possui os seguintes objetivos:

* Permitir que a instituição gerencie sua própria listagem interna de endereços IP que podem acessar o serviço web.

* Assegurar que múltiplos aplicativos da mesma instituição acessando o serviço web não causem uma sobrecarga significativa nos servidores do CNPq, fazendo cache das respostas sempre que possível.

* Preservar a compatibilidade com quaisquer aplicativos existentes. Mudar o endereço do serviço web no arquivo WSDL ou passar por cima da resposta do DNS usando o `/etc/hosts` deve ser suficiente para fazer com que um aplicativo utilize o proxy.

Outra meta deste projeto é servir como um bom exemplo de como criar caches inteligentes de SOAP. A não ser por algumas configurações específicas (`conf/`) e por interceptadores específicos de serviços (`wscallhooks`) em `scripts/cnpqws_cache_key.lua`, o código deve ser bastante genérico e adaptável para realizar cache de outros serviços SOAP.

## Instalando o OpenResty

O [OpenResty](http://openresty.org) é uma plataforma composta pelo [nginx](http://nginx.org), [LuaJIT](http://luajit.org),  e alguns módulos de extensão, em cima da qual nosso proxy foi desenvolvido.

Por favor, siga [as instruções oficiais](http://openresty.org/en/linux-packages.html) do OpenResty para instalar os pacotes para a sua distribuição Linux.

## Instalando o cnpqwsproxy

* Inicialize os submódulos do repositório:

  `git submodule init && git submodule update`

* Gere uma chave privada e o certificado correspondente para o servidor TLS embutido. Você pode mudar as informações de certificado passadas ao openssl por meio da variável de ambiente `TLS_CERT_SUBJ`. Depois chame:

  `make tls-conf`

* Se você quiser usar um certificado TLS válido, assine o `conf/tls/private/cnpqwsproxy.csr` usando sua autoridade certificadora (AC) preferida e sobrescreva `conf/tls/private/cnpqwsproxy.crt` com o certificado fornecido pela AC.

* Edite o `conf/proxyconf.lua`. A opção `wsdl.replacewith` contém uma URL cujo domínio deve ser modificado para o domínio da sua instituição.

  Caso desejado, customize também os tempos de cache neste arquivo. Por favor note que apesar de os currículos terem um cache de 6 meses por padrão, o interceptador `mtimehook` definido em `scripts/cnpqws_cache_key.lua` implica que a data/hora de atualização sempre será buscada para verificar se uma nova versão de um currículo está disponível. A data/hora de modificação tem um cache padrão de somente 15 minutos.

* Adicione as faixas de endereços IP cujo acesso ao proxy deve ser permitido ao arquivo `conf/cnpqws_allowed_clients.conf`. Por padrão, o proxy só aceita requisições de localhost.

* Inicie o aplicativo do proxy:

  `./app start`

## Testando

### Python SUDS

* Instale o ipython e o SUDS:

  `sudo apt-get install ipython python-suds`

* Chame o `ipython` e experimente chamar alguns serviços:

   ```python
   In [1]: import suds
   In [2]: c = suds.client.Client('https://seu-dominio:7443/srvcurriculo/WSCurriculo?wsdl')
   In [3]: c.service.getDataAtualizacaoCV(id='9110045494449064')  # in memoriam
   Out[3]: 27/05/2004 11:39:54
   ```

### Apache CXF

* Instale o Maven.

  `sudo apt-get install maven`

* Clone o repositório [cxf-repl](https://github.com/nitmateriais/cxf-repl):

  `git clone https://github.com/nitmateriais/cxf-repl.git`

* Mude os arquivos WSDL para eles apontarem para o seu domínio:

  `cd cxf-repl`

  `sed -i 's/cnpqwsproxy.ufscar.br/seu-dominio/g' src/main/resources/wsdl/*.wsdl`

* Compile e chame o REPL:

  `make repl`

* Experimente chamar alguns serviços:

  ```python
  >>> import br.cnpq.repositorio.servico.ws.WSCurriculo_Service as WSCurriculo_Service
  >>> service = WSCurriculo_Service()
  >>> port = service.WSCurriculoPort
  >>> port.getDataAtualizacaoCV('9110045494449064')  # in memoriam
  u'27/05/2004 11:39:54'
  ```
