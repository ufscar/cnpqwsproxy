local minutes = 60
local hours = 60*minutes
local days = 24*hours
local months = 30*days
local years = 365*days

return {
	-- Configuration of the upstream server
	upstream = {
		host = 'servicosweb.cnpq.br',
		port = 443,
		-- Timeouts (in ms) for connecting and waiting a response from the server
		timeout = {
			connect  = 500,
			response = 2000,
		},
	},
	-- Configuration of the WSDL filter
	wsdl = {
		-- Original URL present in the WSDL file.
		-- Please escape dots (.) with percent signs (%),
		-- as this is a Lua pattern.
		origpattern = 'http://10%.0%.2%.%d+:8080/',
		-- Base URL of this proxy
		replacewith = 'https://cnpqwsproxy.ufscar.br:7443/',
	},
	-- Configuration of expiry times
	expirytime = {
		-- Filtered WSDL file
		wsdl = 6*months,
		-- Responses which are not SOAP envelopes
		nonsoap = 0,
		-- Responses with empty Envelope->Body->WSCall->return tag
		noreturn = 5,
		-- Specific times for specific WSCall tags
		pertag = {
			['http://ws.servico.repositorio.cnpq.br/:getIdentificadorCNPqResponse'] = 6*months,
			['http://ws.servico.repositorio.cnpq.br/:getIdentificadorCNPqPorUsuarioResponse'] = 6*months,
			['http://br.cnpq.cvlattes.extracaocv/wsdl:getItensDisponiveisResponse'] = 1*months,
		},
		-- Time for tags not listed above
		default = 30*minutes,
	}
}