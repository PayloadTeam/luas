local URLconnect = require("socket.url")

connect = URLconnect.connect = function(url, method, headers, body)
    local protocol, host, port, path, query, fragment = URLconnect.parse(url)
    local sock, err = socket.connect(host, port)
    if not sock then return nil, err end
    if protocol == "https" then
        sock = require("ssl.https").connect(sock)
    end
    if not sock then return nil, err end
    if method then
        local req = string.format("%s %s HTTP/1.1\r\n", method, path)
        for k, v in pairs(headers or {}) do
            req = req .. string.format("%s: %s\r\n", k, v)
        end
        req = req .. "\r\n"
        if body then
            req = req .. body
        end
        sock:send(req)
    end
    return sock
end

function URLconnect.parse(url)
    local protocol, host, port, path, query, fragment = URLconnect.split(url)
    if protocol == "http" then
        port = 80
    elseif protocol == "https" then
        port = 443
    else
        return nil, "unsupported protocol"
    end
    return protocol, host, port, path, query, fragment
end

function URLconnect.split(url)
    local protocol, host, port, path, query, fragment = url:match("^(%a+)://([^:/]+):?(%d*)(/?[^#?]*)%??(.*)#?(.*)$")
    if not protocol then
        protocol, host, port, path, query, fragment = url:match("^(%a+)://([^:/]+)(/?[^#?]*)%??(.*)#?(.*)$")
        if not protocol then
            protocol, host, port, path, query, fragment = url:match("^([^:/]+):?(%d*)(/?[^#?]*)%??(.*)#?(.*)$")
            if not protocol then
                return nil, "invalid url"
            end
            protocol = protocol:lower()
            if protocol == "http" then
                port = 80
            elseif protocol == "https" then
                port = 443
            else
                return nil, "unsupported protocol"
            end
        end
        protocol = protocol:lower()
        if protocol == "http" then
            port = 80
        elseif protocol == "https" then
            port = 443
        else
            return nil, "unsupported protocol"
        end
    end
    if not host then
        return nil, "invalid url"
    end
    if not port then
        port = 80
    end
    if not path then
        path = "/"
    end
    if not query then
        query = ""
    end
    if not fragment then
        fragment = ""
    end
    return protocol, host, port, path, query, fragment
end

function URLconnect.request(url, method, headers, body)
    local protocol, host, port, path, query, fragment = URLconnect.parse(url)
    local sock, err = connect(url, method, headers, body)
    if not sock then return nil, err end
    local response = {}
    local status, err = sock:receive("*l")
    if not status then return nil, err end
    response.status = status
    local headers = {}
    while true do
        local line, err = sock:receive("*l")
        if not line then return nil, err end
        if line == "" then break end
        local name, value = line:match("^(.-):%s*(.*)$")
        if name then
            headers[name:lower()] = value
        end
    end
    response.headers = headers
    if headers["transfer-encoding"] == "chunked" then
        local body = {}
        while true do
            local length, err = sock:receive("*l")
            if not length then return nil, err end
            length = tonumber(length, 16)
            if length == 0 then break end
            local chunk, err = sock:receive(length)
            if not chunk then return nil, err end
            table.insert(body, chunk)
        end
        response.body = table.concat(body)
    else
        local length = tonumber(headers["content-length"])
        if length then
            response.body, err = sock:receive(length)
            if not response.body then return nil, err end
        else
            response.body = ""
            while true do
                local chunk, err = sock:receive(1024)
                if not chunk then return nil, err end
                response.body = response.body .. chunk
            end
        end
    end
    return response
end

for k, v in pairs(URLconnect) do
    _G[k] = v
end

_G.URLconnect = URLconnect.request

function URLconnect.get(url)
    return URLconnect.request(url, "GET")
end

function URLconnect.post(url, body)
    return URLconnect.request(url, "POST", nil, body)
end

function URLconnect.put(url, body)
    return URLconnect.request(url, "PUT", nil, body)
end

function URLconnect.delete(url)
    return URLconnect.request(url, "DELETE")
end

function URLconnect.head(url)
    return URLconnect.request(url, "HEAD")
end

DATA = URLconnect.DATA = "DATA" --[[
    A special value for the body parameter of connect.
    This is useful for sending data from a file.
    The file is not closed when the function returns.
]]

PROXY = URLconnect.PROXY = "PROXY" --[[
    A special value for the headers parameter of connect.
    This is useful for specifying a proxy.
    The proxy is specified as a table with the keys "host" and "port".
]]

[-----------------------------------[ HTTP ]----------------------------------]

HTTP = URLconnect.HTTP = {}
HTTP.VERSION = "1.1"
HTTP.METHODS = {
    GET = "GET",
    HEAD = "HEAD",
    POST = "POST",
    PUT = "PUT",
    DELETE = "DELETE",
    TRACE = "TRACE",
    OPTIONS = "OPTIONS",
    CONNECT = "CONNECT",
}
HTTP.STATUS_CODES = {
    [100] = "Continue",
    [101] = "Switching Protocols",
    [102] = "Processing",
    [200] = "OK",
    [201] = "Created",
    [202] = "Accepted",
    [203] = "Non-Authoritative Information",
    [204] = "No Content",
    [205] = "Reset Content",
    [206] = "Partial Content",
    [207] = "Multi-Status",
    [300] = "Multiple Choices",
    [301] = "Moved Permanently",
    [302] = "Found",
    [303] = "See Other",
    [304] = "Not Modified",
    [305] = "Use Proxy",
    [307] = "Temporary Redirect",
    [400] = "Bad Request",
    [401] = "Unauthorized",
    [402] = "Payment Required",
    [403] = "Forbidden",
    [404] = "Not Found",
    [405] = "Method Not Allowed",
    [406] = "Not Acceptable",
    [407] = "Proxy Authentication Required",
    [408] = "Request Timeout",
    [409] = "Conflict",
    [410] = "Gone",
    [411] = "Length Required",
    [412] = "Precondition Failed",
    [413] = "Request Entity Too Large",
    [414] = "Request-URI Too Long",
    [415] = "Unsupported Media Type",
    [416] = "Requested Range Not Satisfiable",
    [417] = "Expectation Failed",
    [418] = "I'm a teapot",
    [422] = "Unprocessable Entity",
    [423] = "Locked",
    [424] = "Failed Dependency",
    [425] = "Unordered Collection",
    [426] = "Upgrade Required",
    [500] = "Internal Server Error",
    [501] = "Not Implemented",
    [502] = "Bad Gateway",
    [503] = "Service Unavailable",
    [504] = "Gateway Timeout",
    [505] = "HTTP Version Not Supported",
    [506] = "Variant Also Negotiates",
    [507] = "Insufficient Storage",
    [509] = "Bandwidth Limit Exceeded",
    [510] = "Not Extended",
}

[-----------------------------------[ HTTPS ]----------------------------------]

HTTPS = URLconnect.HTTPS = {}
HTTPS.VERSION = "1.1"
HTTPS.METHODS = {
    GET = "GET",
    HEAD = "HEAD",
    POST = "POST",
    PUT = "PUT",
    DELETE = "DELETE",
    TRACE = "TRACE",
    OPTIONS = "OPTIONS",
    CONNECT = "CONNECT",
}
HTTPS.STATUS_CODES = {
    [100] = "Continue",
    [101] = "Switching Protocols",
    [102] = "Processing",
    [200] = "OK",
    [201] = "Created",
    [202] = "Accepted",
    [203] = "Non-Authoritative Information",
    [204] = "No Content",
    [205] = "Reset Content",
    [206] = "Partial Content",
    [207] = "Multi-Status",
    [300] = "Multiple Choices",
    [301] = "Moved Permanently",
    [302] = "Found",
    [303] = "See Other",
    [304] = "Not Modified",
    [305] = "Use Proxy",
    [307] = "Temporary Redirect",
    [400] = "Bad Request",
    [401] = "Unauthorized",
    [402] = "Payment Required",
    [403] = "Forbidden",
    [404] = "Not Found",
    [405] = "Method Not Allowed",
    [406] = "Not Acceptable",
    [407] = "Proxy Authentication Required",
    [408] = "Request Timeout",
    [409] = "Conflict",
    [410] = "Gone",
    [411] = "Length Required",
    [412] = "Precondition Failed",
    [413] = "Request Entity Too Large",
    [414] = "Request-URI Too Long",
    [415] = "Unsupported Media Type",
    [416] = "Requested Range Not Satisfiable",
    [417] = "Expectation Failed",
    [418] = "I'm a teapot",
    [422] = "Unprocessable Entity",
    [423] = "Locked",
    [424] = "Failed Dependency",
    [425] = "Unordered Collection",
    [426] = "Upgrade Required",
    [500] = "Internal Server Error",
    [501] = "Not Implemented",
    [502] = "Bad Gateway",
    [503] = "Service Unavailable",
    [504] = "Gateway Timeout",
    [505] = "HTTP Version Not Supported",
    [506] = "Variant Also Negotiates",
    [507] = "Insufficient Storage",
    [509] = "Bandwidth Limit Exceeded",
    [510] = "Not Extended",
}

function HTTPS.connect(host, port, headers, body)
    local sock = URLconnect.connect(host, port, headers, body)
    sock:send("\r\n\r\n")
    return sock
end

[-----------------------------------[ HTTP/2 ]---------------------------------]
function HTTP2.connect(host, port, headers, body)
    local sock = URLconnect.connect(host, port, headers, body)
    sock:send("\r\n\r\n")
    return sock
end

[-----------------------------------[ HTTP/3 ]---------------------------------]
function HTTP3.connect(host, port, headers, body)
    local sock = URLconnect.connect(host, port, headers, body)
    sock:send("\r\n\r\n")
    return sock
end

[-----------------------------------[ HTTP/4 ]---------------------------------]
function HTTP4.connect(host, port, headers, body)
    local sock = URLconnect.connect(host, port, headers, body)
    sock:send("\r\n\r\n")
    return sock
end

[-----------------------------------[ HTTP/5 ]---------------------------------]
function HTTP5.connect(host, port, headers, body)
    local sock = URLconnect.connect(host, port, headers, body)
    sock:send("\r\n\r\n")
    return sock
end

[-----------------------------------[ HTTP/6 ]---------------------------------]
function HTTP6.connect(host, port, headers, body)
    local sock = URLconnect.connect(host, port, headers, body)
    sock:send("\r\n\r\n")
    return sock
end

[-----------------------------------[ HTTP/7 ]---------------------------------]
function HTTP7.connect(host, port, headers, body)
    local sock = URLconnect.connect(host, port, headers, body)
    sock:send("\r\n\r\n")
    return sock
end

[-----------------------------------[ HTTP/8 ]---------------------------------]
function HTTP8.connect(host, port, headers, body)
    local sock = URLconnect.connect(host, port, headers, body)
    sock:send("\r\n\r\n")
    return sock
end

[-----------------------------------[ HTTP/9 ]---------------------------------]
function HTTP9.connect(host, port, headers, body)
    local sock = URLconnect.connect(host, port, headers, body)
    sock:send("\r\n\r\n")
    return sock
end

[-----------------------------------[ HTTP/10 ]--------------------------------]
function HTTP10.connect(host, port, headers, body)
    local sock = URLconnect.connect(host, port, headers, body)
    sock:send("\r\n\r\n")
    return sock
end

[-----------------------------------[ HTTP/11 ]--------------------------------]
function HTTP11.connect(host, port, headers, body)
    local sock = URLconnect.connect(host, port, headers, body)
    sock:send("\r\n\r\n")
    return sock
end