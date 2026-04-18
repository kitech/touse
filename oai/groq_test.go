package oai

import ("testing"; "os"; "log"; "strings")

func Test111(t *testing.T) {
	res, err := GroqAi(os.Getenv("groqapikey"), "haloo世界")
	log.Println(err)
	log.Println(res)
	if err != nil && strings.Contains(err.Error(), "Forbidden") {
		log.Println("groq forbidden some region IP!!!")
	}
}
