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
			response = 5000,
		},
	},
	-- Configuration of the WSDL filter
	wsdl = {
		-- Original URL present in the WSDL file.
		-- Please escape dots (.) with percent signs (%),
		-- as this is a Lua pattern.
		origpattern = 'http://%d+%.%d+%.%d+%.%d+:8080/',
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
		noreturn = 0,
		-- Specific times for specific WSCall tags
		pertag = {
			['http://ws.servico.repositorio.cnpq.br/:getIdentificadorCNPqResponse'] = 2*years,
			['http://ws.servico.repositorio.cnpq.br/:getIdentificadorCNPqPorUsuarioResponse'] = 2*years,
			['http://ws.servico.repositorio.cnpq.br/:getCurriculoCompactadoResponse'] = 6*months,
			['http://ws.servico.repositorio.cnpq.br/:getCurriculoCompactadoPorUsuarioResponse'] = 6*months,
			['http://ws.servico.repositorio.cnpq.br/:getOcorrenciaCVResponse'] = 0,
			['http://ws.servico.repositorio.cnpq.br/:getOcorrenciaCVPorUsuarioResponse'] = 0,
			['http://br.cnpq.cvlattes.extracaocv/wsdl:getItensDisponiveisResponse'] = 2*months,
			['http://br.cnpq.cvlattes.extracaocv/wsdl:extrairItensResponse'] = 6*months,
		},
		-- Time for tags not listed above
		default = 15*minutes,
	}
}
