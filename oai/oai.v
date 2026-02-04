module oai

import json
import vcp.json as jsonx
import vcp.curlv

pub const chat_path = '/v1/chat/completions'
pub const models_path = '/v1/models'

pub struct Oai {
    pub:
    host   string = 'http://127.0.0.1:5001'
    apikey string
    
    sess_id string
    pmsg_id   i64 // parent_message_id, our go msg 1, first come msg 2
}

pub struct Message {
pub:
    role string = 'user'
    content string
    reasoning_content string
}
pub struct Choise {
pub:
    index int
    finish_reason string // stop
    message Message
}
pub struct Usage {
pub:
    prompt_tokens int
    completion_tokens int
    total_tokens int
    completion_tokens_details struct {
    pub:
        reasoning_tokens int
    }
}
pub struct Resp {
pub:
    id string
    object string
    created i64
    model string
    choices []Choise
    
    usage Usage
}
struct Error1 {
    pub:
    error string
}
pub struct Model {
    pub:
    id string
    object string
    owned_by string
    created i64
}
struct Object {
    pub:
    object string
    data []Model
}

// http://localhost:port
// usage:
// new('key', '')
// .chat('hello')
// .chat_with_model('hello', 'deepseek-chat')
pub fn Oai.new(apikey string, host string) &Oai {
    o := &Oai{}
    o.apikey = apikey
    if host != '' { o.host = host }
    return o
}

pub fn (o &Oai) models() ![]Model {
    uo := curlv.new()
    uo.url(o.host+models_path)
    
    res := uo.get() !
    dump(res.data)
    
    jso := json.decode(Object, res.data) !
    return jso.data
}

pub struct Req {
    pub:
    model string
    stream bool = false
    messages []Message

    sess_id  string  // if empty auto create new one
    pmsg_id   i64
}

pub fn (o &Oai) chat(prompt string) !Resp {
    return o.chat_with_model(prompt, '')!
}
// model: deepseek-chat
pub fn (o &Oai) chat_with_model(prompt string, model string) !Resp {
    
    req := Req {sess_id: o.sess_id, pmsg_id: o.pmsg_id}
    req.model = model
    req.messages << Message{content: prompt}
    data := json.encode(req)

    uo := curlv.new()
    uo.url(o.host+chat_path)
    uo.header('Authorization', 'Bearer ${o.apikey}')
    uo.data_field(data)
    
    res := uo.post() !
    if res.stcode!=200 {
        err := json.decode(Error1, res.data) !
        return errorwc(err.error, res.stcode)
    }
    jso := json.decode(Resp, res.data) !
    if jso.id != '' && jso.id != o.sess_id {
        // not save here, outer save and pass in
        // include sess_id and pmsg_id
        // o.sess_id = jso.id
    }
    return jso
}

pub fn (o &Oai) chat_with_stream(model string) {
    
}


pub fn (o &Oai) txt2img(txt string) {
    
}

pub fn (o &Oai) audio2text() {
    
}

pub fn (o &Oai) audio2tran() {
    
}
