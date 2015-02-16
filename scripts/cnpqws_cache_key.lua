-- This script parses the request body and assembles a $body_cache_key
-- variable containing the SOAP request body parameters.

local pp = require'pp'
local expat = require'expat'

local pp_format  = pp.format
local ngx_req    = ngx.req
local ngx_log    = ngx.log
local ngx_DEBUG  = ngx.DEBUG
local ngx_NOTICE = ngx.NOTICE
local ngx_POST   = ngx.HTTP_POST
local ngx_cap    = ngx.location.capture

-- GET requests have no body, thus it makes no sense to parse them.
-- These are usually done to get the WSDL.
if ngx.var.request_method == 'GET' then return end

-- Assemble a serialized Lua table from the xmlelem children
local function serializetbl(xmlelem)
	local params = {}
	for i,e in ipairs(xmlelem.children) do
		local val
		if #e.children == 0 then
			val = pp_format(e.cdata)
		else
			val = serializetbl(e)
		end
		params[#params+1] = '['..pp_format(e.tag)..']='..val
	end
	table.sort(params) -- Normalize, as param order in the XML does not matter
	return '{'..table.concat(params, ',')..'}'
end

-- Return the SOAP Body given the root XML object
local function soapenvbody(xmlsoap)
	return (xmlsoap
		.tags['http://schemas.xmlsoap.org/soap/envelope/:Envelope']
		.tags['http://schemas.xmlsoap.org/soap/envelope/:Body'])
end

-- Hook into a WSCall to insert a fake parameter containing the CV modification time
local function mtimehook(wscall)
	local id = wscall.tags.id and wscall.tags.id.cdata or
		wscall.tags.request.tags.parametros.tags.idCNPq.cdata
	ngx_log(ngx_DEBUG, "id = ", id)
	-- Request modification time back from the webservice
	local res = ngx_cap('/srvcurriculo/WSCurriculo', {
		method = ngx_POST,
		body = [[<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
				<soap:Body>
					<ns1:getDataAtualizacaoCV xmlns:ns1="http://ws.servico.repositorio.cnpq.br/">
						<id>]]..id..[[</id>
					</ns1:getDataAtualizacaoCV>
				</soap:Body>
			</soap:Envelope>]],
		vars = {
			-- access phase is not run in subrequest, so precompute the cache key
			body_cache_key = [[http://ws.servico.repositorio.cnpq.br/:getDataAtualizacaoCV|{['id']=']]..id..[['}]],
		}
	})
	if res.status ~= 200 then error(pp_format(res)) end
	-- Parse response
	local xmlres = expat.treeparse({string=res.body, namespacesep=':'})
	local mtime = (
		soapenvbody(xmlres)
		.tags['http://ws.servico.repositorio.cnpq.br/:getDataAtualizacaoCVResponse']
		.tags['return']
		.cdata)
	ngx_log(ngx_DEBUG, "mtime = ", mtime)
	-- Add a fake parameter to the original request
	local children = wscall.children
	children[#children+1] = {tag = "_mtime", children = {}, cdata = mtime}
end

-- Special hooks for certain webservice calls
local wscallhooks = {
	['http://ws.servico.repositorio.cnpq.br/:getCurriculoCompactado'] = mtimehook,
	['http://ws.servico.repositorio.cnpq.br/:getCurriculoCompactadoPorUsuario'] = mtimehook,
	['http://br.cnpq.cvlattes.extracaocv/wsdl:extrairItens'] = mtimehook,
}

local headers = ngx_req.get_headers()
local contenttype = headers['content-type']

-- As far as we know, the server only accepts POST requests containing XML data.
-- Anyway, if it is not the case, we return and let the nginx config do the fallback.
if not contenttype or not contenttype:match('^text/xml') then
	ngx_log(ngx_NOTICE, 'Unsupported content-type: ', pp_format(contenttype))
	return
end

-- Try to get the charset from the Content-Type header. If not specified, the
-- variable will be nil, and thus ignored by expat, which will use the default
-- charset (utf-8), or the one specified in the <?xml ?> tag, if present.
local charset = contenttype:match(';%s*charset=([^;]+)')

-- Parse the request body
ngx_req.read_body()
local xmlsoap = expat.treeparse({
	string=ngx_req.get_body_data(),
	namespacesep=':',
	encoding=charset})

-- Get the tag contained inside the SOAP Body
local wscall = soapenvbody(xmlsoap).children[1]

-- Check if any hook exists for this WSCall
local hook = wscallhooks[wscall.tag]
if hook then
	local ok, err = pcall(hook, wscall)
	if not ok then ngx_log(ngx_NOTICE, err) end
end

-- The cache key is formed by the tag name, that indicates which
-- webservice call is being made, and by a serialized Lua table
-- containing the parameters.
local cachekey = wscall.tag..'|'..serializetbl(wscall)
ngx_log(ngx_DEBUG, "cachekey: ", cachekey)
ngx.var.body_cache_key = cachekey
