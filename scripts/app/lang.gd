class_name Lang
extends RefCounted
## Idioma do jogo (RF-5.07): português ou inglês. "" = segue o aparelho
## (português se o aparelho estiver em português; qualquer outro idioma → inglês).

const LOCALES := ["pt_BR", "en"]
const NAMES := {"pt_BR": "Português", "en": "English"}


## Locale efetivo para a escolha `lang` ("" = automático).
static func resolve(lang: String, device_language := "") -> String:
	if lang in LOCALES:
		return lang
	if device_language == "":
		device_language = OS.get_locale_language()
	return "pt_BR" if device_language == "pt" else "en"


static func apply(lang: String) -> void:
	TranslationServer.set_locale(resolve(lang))


## Próximo idioma da lista (o botão de Opções alterna entre os dois).
static func next(current: String) -> String:
	var i := LOCALES.find(resolve(current))
	return LOCALES[(i + 1) % LOCALES.size()]
