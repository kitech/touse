module oai

import os

//import json
import vcp.json as jsonx
import vcp.curlv

pub const mset_auth_url = 'https://edge.microsoft.com/translate/auth'
pub const mset_api_url_fixed = 'https://api.cognitive.microsofttranslator.com/translate?from=en&to=zh-CHS&api-version=3.0&includeSentenceLength=true'
pub const mset_ua = 'msie 6'

// to zh-CHS
pub fn mset_api_url(tolang string, fromlang string) string {
	fromlang = ''
	
	return 'https://api.cognitive.microsofttranslator.com/translate?from=${fromlang}&to=${tolang}&api-version=3.0&includeSentenceLength=true'
}

// to zh
pub fn mset_tran(text string) !string {
	res := mset_tran_full('zh', '', text) !
	return res[0]
}
pub fn mset_tran_en(text string) !string {
	res := mset_tran_full('en', '', text) !
	return res[0]
}

pub fn mset_tran_full(tolang string, fromlang string, texts ... string) ![]string {
	assert tolang!=''
	assert texts.len>0

	static apikey_ := '' // seems about 30min
	
	if apikey_ == '' {
		apikey_ = mset_get_key(false) !
	}

	req := jsonx.encode(texts.map(|x| MsetReq{x}))
	retrycnt := 0
	retry: if retrycnt++ > 1 { return error('faild retry') }
	
	co := curlv.new().verbose(false)
	co.url(mset_api_url(tolang, fromlang))
	co.bearer_auth(apikey_)
	co.useragent('msie 6')
	co.header('content-type', 'application/json')
	co.data_field(req)

	rsp := co.post() !
	// dump(rsp)
	
	decerr := false
	res := jsonx.decode[Response](rsp.data) or {
		decerr = true
		if !err.str().contains('.t_array') {
			println(err)
		}
		omitor(err)
	}
	if decerr {
		rr := jsonx.decode[[]Response](rsp.data) !
		res = rr[0]
	}
	if res.error.code == 401001 {
		apikey_ = mset_get_key(true) !
		goto retry
	} else if res.error.code != 0 {
	
		return errorwc(res.error.message, res.error.code)
	}
dump(res)
	return res.translations.map(|x| x.text)
}

pub fn mset_get_key(renew bool) !string {
	keyfile := os.join_path(os.temp_dir(), 'mset_apikey.txt')
	
	key := os.read_file(keyfile) or { omitor(err) }
	if key == '' || renew {
		co := curlv.new().url(mset_auth_url).verbose(false).useragent('msie 6')
		rsp := co.get() !
		println(rsp.data)
		if rsp.stcode != 200 {
			return errorwc(rsp.stline, rsp.stcode)
		}
		key = rsp.data
		os.write_file(keyfile, rsp.data) or { omitor(err) }
	}
	return key
}

struct MsetReq { pub: text string }

pub struct Response {
pub:
	// when from empty
	detectedLanguage struct {
		language string
		score f32
	} @[json: detectedLanguage]
	
	translations []struct {
		text string
		to string
		
		sentLen struct {
			srcSentLen	[]int
			transSentLen []int
		}
	}
	
	error struct {
		code	int
		message 	string
	}
}

// hehe edge good [{"translations":[{"text":"呵呵，边缘不错","to":"zh-Hans","sentLen":{"srcSentLen":[14],"transSentLen":[7]}}]}]'
