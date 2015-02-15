-- This script implements a proxy to the remote upstream SOAP server,
-- which establishes an expiry time for each response (by setting the
-- X-Accel-Expires header) and filters WSDL files to change the
-- endpoint location.

local http = require'resty.http'
local expat = require'expat'

local proxyconf = require'conf.proxyconf'
local expirytime = proxyconf.expirytime
local HOST = proxyconf.upstream.host
local PORT = proxyconf.upstream.port
local CONN_TIMEOUT = proxyconf.upstream.timeout.connect
local RESP_TIMEOUT = proxyconf.upstream.timeout.response

local str_lower  = string.lower
local ngx_log    = ngx.log
local ngx_DEBUG  = ngx.DEBUG
local ngx_NOTICE = ngx.NOTICE

-- Parse response body and establish an expiry time
local function calctime(body)
	local ok, xmlsoap = pcall(expat.treeparse, {
		string=body,
		namespacesep=':'})
	if not ok then
		ngx_log(ngx_NOTICE, "Got non-XML response: ", xmlsoap)
		return expirytime.nonsoap
	end

	local env = xmlsoap.children[1]
	if env.tag ~= 'http://schemas.xmlsoap.org/soap/envelope/:Envelope' then
		ngx_log(ngx_NOTICE, "Got non-SOAP response, tag: ", env.tag)
		return expirytime.nonsoap
	end

	local wscall = (env
		.tags['http://schemas.xmlsoap.org/soap/envelope/:Body']
		.children[1])
	if wscall.tag == 'http://schemas.xmlsoap.org/soap/envelope/:Fault' then
		error(wscall.tags['faultstring'].cdata)
	end

	local wsret = wscall.tags['return']
	if not wsret.cdata and #wsret.children==0 then
		return expirytime.noreturn
	end

	ngx_log(ngx_DEBUG, "WSCall tag: ", wscall.tag)
	local t = expirytime.pertag[wscall.tag]
	if t then return t end

	return expirytime.default
end

-- Copied from resty.http (not accessible in this scope)
-- http://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html#sec13.5.1
local HOP_BY_HOP_HEADERS = {
	["connection"]          = true,
	["keep-alive"]          = true,
	["proxy-authenticate"]  = true,
	["proxy-authorization"] = true,
	["te"]                  = true,
	["trailers"]            = true,
	["transfer-encoding"]   = true,
	["upgrade"]             = true,
	["content-length"]      = true, -- Not strictly hop-by-hop, but Nginx will deal 
	                                -- with this (may send chunked for example).
}

-- Based on httpc:proxy_response, but buffers the entire response,
-- filters it in the case it is a WSDL, otherwise just calls
-- calctime to establish an expiry time.
local function proxy_response(response)
	-- Please note that errors (besides appearing in the error_log)
	-- will be treated by the downstream proxy, which will send a
	-- stale cache response to the client.
	if not response then error("no response provided") end

	ngx.status = response.status
	
	-- Filter out hop-by-hop headeres
	for k,v in pairs(response.headers) do
		if not HOP_BY_HOP_HEADERS[str_lower(k)] then
			ngx.header[k] = v
		end
	end

	local body = response:read_body()
	local accelexpires
	if ngx.var.args == 'wsdl' then
		body = body:gsub(proxyconf.wsdl.origpattern, proxyconf.wsdl.replacewith)
		accelexpires = expirytime.wsdl
	else
		accelexpires = calctime(body)
	end
	ngx_log(ngx_DEBUG, "accelexpires: ", accelexpires)
	ngx.header["X-Accel-Expires"] = accelexpires
	ngx.print(body)
end

local httpc = http.new()
httpc:set_timeout(CONN_TIMEOUT)
local ok, err = httpc:connect(HOST, PORT)
if not ok then error(err) end
local ok, err = httpc:ssl_handshake(nil, HOST, true)
if not ok then error(err) end

httpc:set_timeout(RESP_TIMEOUT)
proxy_response(httpc:proxy_request())
httpc:set_keepalive()