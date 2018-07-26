local json = require "cjson"
local uuid = require 'docker.jit-uuid'

local bad_message = json.encode({
    ret_code = 9000,
    ret_msg = "something wrong happened in openresty"
})
local bad_info = {
    ret_code = 9000,
    ret_msg = "something wrong happened in openresty"
}

------------------------function------------------------

local function get_meta_data()
    local resty_md5 = require "resty.md5"
    local resty_upl = require "resty.upload"
    local resty_str = require "resty.string"
    local meta = {
        md5= {},
        name= {},
        size= {},
        path= {},
        content_type= {}
    }
    local fname, file_obj
    local field, value, path
    local rmd5 = resty_md5:new()
    local form, err = resty_upl:new(4096)

    if not form then
        return nil, err
    end

    while true do
        local typ, res, err = form:read()
        if not typ then
            return nil, "body read error"
        end
        if typ == "header" then
            if res[1] == "Content-Disposition" then
                field = string.match(res[2], "%s+name=\"([^\"]+)\"")
                fname = string.match(res[2], "%s+filename=\"([^\"]+)\"")
                if fname then
                    path = "/tmp/"..uuid()
                    table.insert(meta.name, fname)
                    table.insert(meta.path, path)
                    file = io.open(path, "wb+")
                    if not file then
                        return nil, "file create error"
                    end
                else 
                    meta[field] = nil
                end
            elseif res[1] == "Content-Type" then
                table.insert(meta.content_type, res[2])
            else
                return nil, "body format error"
            end
         elseif typ == "body" then
            if file then
                file:write(res)
                rmd5:update(res)
            else
                if value then
                    value = value .. res
                else
                    value = res
                end
            end
        elseif typ == "part_end" then
            if file then
                table.insert(meta.md5, resty_str.to_hex(rmd5:final()))
                table.insert(meta.size, file:seek("cur", 0))
                rmd5:reset()
                file:close()
                file = nil
            else
                meta[field] = value
                value = nil
            end
        elseif typ == "eof" then
            return meta, ""
        else
            return nil, "body read error"
        end
    end
end

local function format_single(meta)
    local new = {}
    for k, v in pairs(meta) do
        if type(v)=="table" then
            new[k] = v[1]
        else 
            new[k] = v
        end
    end
    return new
end

local function format_multi(meta)
    local new = {}
    for k, v in pairs(meta) do
        if type(v)~="table" or table.getn(v)>0 then
            new[k] = v
        end
    end
    return new
end

local function upload_media(format_meta)
    local function inner_func(inner_uri)
        local res, info
        local meta, err = get_meta_data()
        if not meta then
            bad_info.ret_msg = err
            ngx.status = ngx.HTTP_BAD_REQUEST
            ngx.print(json.encode(bad_info))
            ngx.exit(ngx.HTTP_BAD_REQUEST)
        end

        local body = json.encode(format_meta(meta))

        ngx.req.set_header("Content-Type", "application/json")
        ngx.header.content_type = "application/json"
        res = ngx.location.capture(inner_uri,
            {
                method=ngx.HTTP_POST,
                body=body,
            }
        )
        info = json.decode(res.body)
        if info.ret_code > 0 then
            ngx.status = res.status
            ngx.print(res.body)
            ngx.exit(res.status)
        end

        for i, value in ipairs(info.minio_upload_urls) do
            ngx.req.set_header("minio_upload_file", meta.path[i])
            ngx.req.set_header("minio_upload_url", value)
            res = ngx.location.capture("/minio/upload/",{method=ngx.HTTP_PUT, body=""})
            if res.status >= 400 then
                ngx.status = res.status
                ngx.print(bad_message)
                ngx.exit(res.status)
            end
            meta.path[i] = info["minio_names"][i]
        end

        body = json.encode(format_meta(meta))
        res  = ngx.location.capture(inner_uri,
            {
                method = ngx.HTTP_PUT,
                body=body
            }
        )
        ngx.status = res.status
        ngx.print(res.body)
        ngx.exit(res.status)
    end
    return inner_func
end

local function download_media(inner_uri)
    local res, info

    res = ngx.location.capture(inner_uri,
        {
            method=ngx.HTTP_GET,
            args=ngx.var.query_string,
            body=json.encode(meta),
        }
    )
    info = json.decode(res.body)
    if info.ret_code > 0 then
        ngx.status = res.status
        ngx.print(res.body)
        ngx.exit(res.status)
    end
    ngx.req.set_header("minio_download_url", info.minio_download_url)
    ngx.req.set_header("content_type", info.content_type)
    ngx.req.set_header("content_disposition", info.content_disposition)
    return ngx.exec("/minio/download/")
end

------------------------main------------------------
local method = ngx.req.get_method()
local uri = string.gsub(ngx.var.uri, "/", "_")

local CONFIG = {
    _util_image_= {
        GET=download_media,
        POST=upload_media(format_single),
        INNER_URL="/util/minio/image/",
    },
    _media_resource_= {
        GET=download_media,
        POST=upload_media(format_single),
        INNER_URL="/media/minio/resource/",
    },
    _zone_post_= {
        POST=upload_media(format_multi),
        INNER_URL="/zone/minio/post/",
    },
    _zone_media_= {
        GET=download_media,
        INNER_URL="/zone/minio/media/",
    },
}

local inner_uri = CONFIG[uri].INNER_URL
local inner_fun = CONFIG[uri][method]

if not inner_fun then
    return ngx.exec(inner_uri, ngx.var.query_string)
end

inner_fun(inner_uri)

