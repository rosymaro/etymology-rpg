"""어원 조각의 '단어 속 모양'(form)을 실제 철자에 맞춘다(사용자 의견).

단어장 데이터의 현대 형태(예: esse → ess)가 철자에 없으면(presentation) 예전에는 그 조각을 자르지 않았다.
이제는 철자에 있는 글자로 자르고(pre + sent + ation), 원래 형태는 base에 남겨 '변형'으로 설명한다.
  1) 사람이 검토해 정한 값(OVERRIDES)  2) 어근의 알려진 변형(VARIANTS)  3) 가장 닮은 글자(fuzzy)
철자에 모양이 전혀 남지 않은 조각은 lost: true(form "")로 두고, 설명에서 "모양이 사라졌다"고 말한다.
결과 etym: {root, meaning, form(단어 속 글자), at(글자 자리), base(원래 형태, 바뀐 때만), lost(사라진 때만)}
"""
import difflib

# 자주 나오는 어근의 현대 영어 변형. 앞에 있는 것부터 찾는다.
VARIANTS = {
    'facere': ['fect', 'fic', 'fac', 'feat', 'feas', 'feit', 'fet', 'fit', 'fair', 'fash', 'fy', 'fi', 'fa', 'f'],
    'capere': ['ceiv', 'cept', 'cip', 'cup', 'cap', 'chas', 'catch', 'cab', 'cov', 'cei', 'ce', 'c'],
    'caput': ['chiev', 'chapt', 'capt', 'cap', 'cad', 'cat', 'chef', 'chief', 'ch'],
    'spectare': ['spect', 'spic', 'spec', 'spis', 'spi', 'spy'],
    'speciēs': ['spic', 'spec', 'spi'],
    'stare': ['stant', 'stanc', 'sist', 'stan', 'sta', 'st'],
    'sistere': ['sist', 'st'],
    'dis-': ['dis', 'des', 'dif', 'di', 'de', 's'],
    'de-': ['de', 'di', 'd'],
    'in-': ['in', 'im', 'il', 'ir', 'an', 'en', 'em', 'i'],
    'ex-': ['ex', 'ef', 'es', 'e', 's'],
    'sub-': ['sub', 'suc', 'suf', 'sug', 'sum', 'sup', 'sur', 'sus', 'su', 'sou', 's'],
    'ad-': ['ad', 'ac', 'af', 'ag', 'al', 'an', 'ap', 'ar', 'as', 'at', 'a'],
    'ob-': ['ob', 'oc', 'of', 'op', 'o'],
    'com-': ['com', 'con', 'col', 'cor', 'co', 'c'],
    're-': ['re', 'r'],
    'trans-': ['trans', 'tra', 'tre', 'tr'],
    'inter-': ['inter', 'intel', 'enter', 'entre', 'inti', 'int'],
    'pro-': ['pro', 'pru', 'por', 'pur', 'pr'],
    'prae-': ['pre', 'pri', 'pr'],
    'per-': ['per', 'pil', 'pel', 'pe'],
    'syn-': ['syn', 'sym', 'syl', 'sy'],
    'se-': ['se', 'so', 'su', 's'],
    'en (em-)': ['en', 'em', 'in', 'i'],
    'epi-': ['epi', 'bish', 'bi'],
    'para-': ['para', 'pa'],
    'ante-': ['ante', 'anti', 'ant'],
    'videre': ['view', 'vid', 'vis', 'vic', 'vey', 'vy', 'vi', 'v'],
    'ferre': ['fer', 'lat', 'la', 'l'],
    'esse (futurus)': ['sent', 'senc', 'ess', 'est', 'es', 's'],
    'noscere (notitia)': ['gniz', 'gnit', 'gnor', 'quaint', 'naiss', 'not', 'gn', 'no', 'n'],
    'legere': ['lect', 'lig', 'leg', 'lit', 'less', 'log', 'les', 'li', 'l'],
    'plere (plenus)': ['plet', 'pli', 'ply', 'ple', 'pl'],
    'tenere': ['tain', 'tin', 'ten', 't'],
    'trahere': ['tract', 'treat', 'trai', 'tra', 'tre', 'tr'],
    'ligare': ['loy', 'li', 'ly', 'l'],
    'dicere': ['dict', 'dic', 'dex', 'dit', 'dg', 'di', 'd'],
    'agere (actus)': ['act', 'ag', 'ig', 'ay', 'a'],
    'currere': ['curr', 'cour', 'cur', 'cours'],
    'ire (exire)': ['it', 'ien', 'enc', 'i'],
    'dare (datum)': ['dat', 'dit', 'dow', 'dic', 'di', 'do', 'd'],
    'regere': ['reg', 'rul', 'rai', 're', 'r'],
    'mittere': ['miss', 'mis', 'mit', 'mes', 'm'],
    'putare (computare)': ['count', 'put', 'pt'],
    'opus (opera)': ['oper', 'of', 'op', 'o'],
    'stinguere': ['stinct', 'sting', 'stig', 'stin', 'st'],
    'prehendere': ['prehend', 'prehens', 'pren', 'pre', 'pri', 'pr'],
    'cura': ['cur', 'sur', 'cu', 'su'],
    'tornare (tornus)': ['turn', 'tour', 'tor', 'tou'],
    'sequi': ['sequ', 'secu', 'sec', 'sue', 'su'],
    'stringere (strictus)': ['strict', 'stress', 'strait', 'strai', 'stig', 'str'],
    'super': ['super', 'supr', 'sover', 'sopr', 'sur', 'sup'],
    'theos': ['theo', 'thus', 'the', 'th'],
    'emere': ['empt', 'emp', 'amp', 'ans', 'em'],
    'gratus': ['grat', 'grac', 'gree', 'gra'],
    'serere (satio)': ['sert', 'ser', 'er'],
    'cernere (certus)': ['cern', 'cret', 'cree', 'crim', 'cr'],
    'ius (iustus)': ['jus', 'jud', 'ju'],
    'movere': ['mov', 'mot', 'mob', 'mut', 'mo'],
    'cor (cordis)': ['cord', 'cour', 'cor'],
    'locus': ['loc', 'low', 'lieu', 'lou', 'lo'],
    'cedere': ['ced', 'ceas', 'cess', 'ces', 'ce'],
    'cadere': ['cas', 'cid', 'chanc', 'chut', 'cay', 'cha', 'che', 'ca'],
    'vertere': ['vert', 'vers', 'vort', 'vorc', 'ver', 'vor', 'ros'],
    'struere': ['struct', 'stroy', 'stru', 'str'],
    'spirare (spiritus)': ['spir', 'pir'],
    'ballein': ['bol', 'bal', 'vil', 'l'],
    'parare': ['par', 'per', 'pir'],
    'tangere': ['tang', 'tact', 'ting', 'tag', 'tam', 'tai', 'ta'],
    'sedere': ['sed', 'sid', 'sess', 'siz', 'sieg', 'si'],
    'pendere': ['pend', 'pens', 'pound', 'pond', 'pen', 'pon'],
    'fundere': ['fus', 'fund', 'fun', 'fon', 'fu'],
    'scandere': ['scend', 'scens', 'scent', 'scan'],
    'ponere': ['pos', 'pon', 'pound', 'pot', 'po'],
    'warder': ['ward', 'guard', 'gard', 'gar', 'war', 'ard'],
    'weard': ['ward', 'ard'],
    'sēon': ['sigh', 'see', 's'],
    'los (losian)': ['less', 'lose', 'los'],
    'probare': ['proof', 'prob', 'prov', 'pro'],
    'quattuor (quadra)': ['quadr', 'quar', 'quad', 'squar', 'qua'],
    'gerere (gestus)': ['gest', 'gist', 'ger', 'g'],
    'rota (rotulus)': ['round', 'roll', 'roul', 'rot', 'rol', 'rod', 'ro'],
    'agein': ['ag', 'eg', 'g'],
    'pirat': ['pir', 'per'],
    'peiran': ['pirat', 'pir', 'per'],
    'crescere': ['cresc', 'cruit', 'crew', 'cre', 'cr'],
    'magnus (maior)': ['magn', 'may', 'mas', 'mis', 'ma', 'm'],
    'histanai': ['stem', 'stat', 'st'],
}

# 사람이 하나하나 검토해 정한 값: 단어 -> {원래 form: 단어 속 글자}. "" = 이 단어에서 모양이 사라짐(lost).
OVERRIDES = {
    'devil': {'dia': 'de', 'bol': 'vil'}, 'wizard': {'wit': 'wiz'}, 'disperse': {'dis': 'di', 'spers': 'spers'},
    'shuffle': {'shove': 'shuff'}, 'drier': {'dry': 'dri'}, 'furniture': {'form': 'furn'},
    'migraine': {'hemi': 'mi', 'crani': 'grain'}, 'wrought': {'work': 'wrought'}, 'playwright': {'work': 'wright'},
    'diarrhea': {'rhythm': 'rrhe'}, 'surgeon': {'urg': 'rg'}, 'surgery': {'urg': 'rg'}, 'surgical': {'urg': 'rg'},
    'biker': {'cycl': 'bik'}, 'bike': {'cycl': 'bik'}, 'peacock': {'pāvō': 'pea'}, 'apron': {'map': 'apr'},
    'relish': {'lax': 'lish'}, 'roulette': {'rot': 'roul'}, 'interpret': {'pric': 'pret'},
    'interpretation': {'pric': 'pret'}, 'interpreter': {'pric': 'pret'}, 'allegedly': {'leg': 'leg'},
    'sober': {'ebri': 'ber'}, 'funnel': {'in': '', 'fus': 'fun'}, 'forgery': {'fabr': 'forg'}, 'forge': {'fabr': 'forg'},
    'bishop': {'scope': 'hop'}, 'nice': {'sci': 'ic'}, 'nicely': {'sci': 'ic'}, 'handwritten': {'write': 'writ'},
    'gossip': {'good': 'gos', 'sib': 'sip'}, 'deny': {'neg': 'ny'}, 'undeniable': {'neg': 'ni'}, 'denial': {'neg': 'ni'},
    'crate': {'grill': 'crat'}, 'vinegar': {'acr': 'egar'}, 'reverend': {'rever': 'rever'}, 'reverence': {'rever': 'rever'},
    'impeachment': {'ped': 'peach'}, 'infringement': {'fract': 'fring'}, 'controller': {'rol': 'roll'},
    'adjacent': {'ject': 'jac'}, 'sheriff': {'riff': 'riff'}, 'stray': {'vag': 'tray'}, 'hamlet': {'home': 'ham'},
    'renowned': {'nom': 'nown'}, 'manure': {'oper': 'ur'}, 'orchard': {'yard': 'chard'}, 'marvel': {'mir': 'marv'},
    'marvelous': {'mir': 'marv'}, 'recruit': {'cresc': 'cruit'}, 'recruiter': {'cresc': 'cruit'},
    'recruitment': {'cresc': 'cruit'}, 'crew': {'cresc': 'crew'}, 'prose': {'vert': 'se'}, 'obey': {'aud': 'bey'},
    'obedience': {'aud': 'bed'}, 'disobedience': {'aud': 'bed'}, 'dime': {'dec': 'dim'}, 'task': {'tax': 'tas'},
    'embassy': {'ambass': 'embass'}, 'cassette': {'cash': 'cass'}, 'amendment': {'mend': 'mend'},
    'amend': {'ex': 'a', 'mend': 'mend'}, 'parsley': {'petr': 'pars'}, 'burden': {'bear': 'burd'}, 'overt': {'aper': 'vert'},
    'invoice': {'via': 'voic'}, 'mortgage': {'wage': 'gage'}, 'engagement': {'wage': 'gage'}, 'engage': {'wage': 'gage'},
    'dinner': {'jun': 'inn'}, 'medley': {'mix': 'med'}, 'achievable': {'cap': 'chiev'}, 'achieve': {'cap': 'chiev'},
    'achievement': {'cap': 'chiev'}, 'latter': {'late': 'latt'}, 'sewer': {'aqua': 'ew'}, 'sewage': {'aqua': 'ew'},
    'propagation': {'pact': 'pag'}, 'propaganda': {'pact': 'pag'}, 'cue': {'queue': 'cue'},
    'conveyor': {'via': 'vey'}, 'convey': {'via': 'vey'}, 'detachment': {'stake': 'tach'}, 'attach': {'stake': 'tach'},
    'torch': {'tort': 'torc'}, 'abortion': {'ori': 'ort'}, 'abort': {'ori': 'ort'}, 'rejoice': {'joy': 'joic'},
    'soar': {'aura': 'oar'}, 'scarce': {'carp': 'carc'}, 'scarcely': {'carp': 'carc'}, 'streak': {'strike': 'streak'},
    'window': {'eye': 'ow'}, 'upstairs': {'step': 'stair'}, 'nonetheless': {'one': 'one'}, 'judge': {'dict': 'dge'},
    'dogma': {'dox': 'dog'}, 'costume': {'suet': 'stum'}, 'hefty': {'heave': 'heft'}, 'explosion': {'plaud': 'plos'},
    'explosive': {'plaud': 'plos'}, 'grotesque': {'crypt': 'grot'}, 'fabulous': {'fat': 'fab'}, 'cater': {'cap': 'cat'},
    'illumination': {'in': 'il', 'lumin': 'lumin'}, 'illuminate': {'in': 'il', 'lumin': 'lumin'}, 'hemp': {'cannab': 'hemp'},
    'frenzy': {'phren': 'fren'}, 'frantic': {'phren': 'fran'}, 'fence': {'de': '', 'fend': 'fenc'},
    'neighbor': {'near': 'neigh'}, 'neighborhood': {'near': 'neigh'}, 'cowardly': {'queue': 'cow'}, 'coward': {'queue': 'cow'},
    'grief': {'grav': 'grie'}, 'hatred': {'hate': 'hat'}, 'biopsy': {'opt': 'ops'}, 'autopsy': {'opt': 'ops'},
    'synopsis': {'opt': 'ops'}, 'dawn': {'day': 'daw'}, 'foster': {'food': 'fos'}, 'umpire': {'neg': 'um', 'par': 'pire'},
    'defy': {'fid': 'fy'}, 'nonstop': {'neg': 'non'}, 'nonfiction': {'neg': 'non'}, 'agreeable': {'ad': 'a', 'gree': 'gree'},
    'agree': {'ad': 'a', 'gree': 'gree'}, 'disagree': {'gree': 'gree'}, 'agreement': {'ad': 'a', 'gree': 'gree'},
    'disagreement': {'gree': 'gree'}, 'meanwhile': {'medi': 'mean'}, 'meantime': {'medi': 'mean'}, 'vantage': {'van': 'vant'},
    'vanguard': {'van': 'van', 'ward': 'guard'}, 'distance': {'dis': 'di', 'sta': 'stan'}, 'distant': {'dis': 'di', 'sta': 'stan'},
    'extant': {'ex': 'ex', 'sta': 'tant'}, 'vowel': {'voc': 'vow'}, 'maneuver': {'oper': 'euv'}, 'preach': {'dict': 'ach'},
    'preacher': {'dict': 'ach'}, 'commencement': {'it': 'menc'}, 'commence': {'it': 'menc'}, 'ballpark': {'pill': 'ball'},
    'balloon': {'pill': 'ball'}, 'treacherous': {'trick': 'treach'}, 'couch': {'loc': 'uch'}, 'exile': {'sal': 'il'},
    'monoxide': {'mono': 'mon', 'oxy': 'ox'}, 'pregnancy': {'nat': 'gn'}, 'pregnant': {'nat': 'gn'},
    'manslaughter': {'slay': 'slaugh'}, 'onslaught': {'slay': 'slaugh'}, 'unpaid': {'pac': 'pai'}, 'ambiguous': {'act': 'gu'},
    'ambiguity': {'act': 'gu'}, 'guise': {'wise': 'guise'}, 'clad': {'cloth': 'clad'}, 'cinema': {'graph': 'ema'},
    'transatlantic': {'atlas': 'atlant'}, 'ascension': {'scan': 'scens'}, 'wherever': {'ever': 'ever'},
    'standard': {'hard': 'dard'}, 'disk': {'disc': 'disk'}, 'mascara': {'mask': 'masc'}, 'dungeon': {'domin': 'dung'},
    'viability': {'viv': 'via'}, 'viable': {'viv': 'via'}, 'registrar': {'ger': 'gist'}, 'registry': {'ger': 'gist'},
    'register': {'ger': 'gist'}, 'registration': {'ger': 'gist'}, 'daisy': {'day': 'dais'}, 'graft': {'graph': 'graf'},
    'absorption': {'sorb': 'sorp'}, 'accomplice': {'plex': 'plic'}, 'carnival': {'lev': 'val'}, 'equip': {'ship': 'quip'},
    'equipment': {'ship': 'quip'}, 'indigestion': {'gerere': 'gest'}, 'respiration': {'spirare': 'spir'},
    'seam': {'sew': 'seam'}, 'seamless': {'sew': 'seam'}, 'hotel': {'hosp': 'hot'}, 'plague': {'plain': 'plag'},
    'macho': {'masc': 'mach'}, 'sergeant': {'serv': 'serg'}, 'treason': {'dat': 'as'}, 'wisdom': {'wit': 'wis'},
    'cavity': {'cage': 'cav'}, 'excavation': {'cage': 'cav'}, 'dozen': {'du': 'do', 'dec': 'zen'},
    'nomenclature': {'cil': 'cla'}, 'steward': {'ward': 'ard'}, 'stewardship': {'ward': 'ard'},
    'woman': {'man': 'man'}, 'sure': {'cur': 'ur'}, 'surely': {'cur': 'ur'}, 'assure': {'cur': 'ur'},
    'spite': {'de': '', 'spect': 'spite'}, 'nurture': {'nutri': 'nurt'}, 'entity': {'ess': 'ent'},
    'treble': {'tri': 'tre'}, 'measurable': {'meter': 'meas'}, 'ancestor': {'ced': 'ces'}, 'ancestral': {'ced': 'ces'},
    'ancestry': {'ced': 'ces'}, 'spouse': {'spond': 'spous'}, 'platoon': {'pill': 'plat'}, 'charm': {'cant': 'char'},
    'despair': {'sper': 'spair'}, 'seal': {'sign': 'seal'}, 'wilderness': {'deer': 'der'}, 'entirely': {'tir': 'tir'},
    'entire': {'tir': 'tir'}, 'nozzle': {'nose': 'noz'}, 'epidemiology': {'demo': 'dem'}, 'purge': {'act': 'g'},
    'prominent': {'mount': 'min'}, 'ledger': {'lay': 'led'}, 'phosphate': {'phor': 'phos'}, 'remnant': {'man': 'mn'},
    'tray': {'tree': 'tray'}, 'cabbage': {'cap': 'cab'}, 'kitty': {'cat': 'kit'}, 'kitten': {'cat': 'kit'},
    'pigeon': {'pip': 'pig'}, 'incense': {'cand': 'cens'}, 'muster': {'mon': 'mus'}, 'torment': {'tort': 'torm'},
    'truce': {'tree': 'truc'}, 'heartfelt': {'feel': 'felt'}, 'truthfully': {'tree': 'truth'}, 'truthful': {'tree': 'truth'},
    'combo': {'bin': 'bo'}, 'bless': {'blood': 'bless'}, 'infancy': {'fat': 'fan'}, 'syllable': {'lemma': 'lab'},
    'auxiliary': {'auct': 'aux'}, 'tomorrow': {'morn': 'morrow'}, 'dialect': {'log': 'lect'}, 'intrigue': {'tric': 'trig'},
    'toilet': {'text': 'toil'}, 'crouch': {'crook': 'crou'}, 'forfeit': {'forest': 'for', 'fac': 'feit'},
    'buffalo': {'bov': 'buff'}, 'eagle': {'aquil': 'eagl'}, 'savvy': {'sap': 'sav'}, 'anthem': {'phon': 'them'},
    'grant': {'cred': 'gran'}, 'pride': {'prov': 'pri'}, 'ambient': {'it': 'i'}, 'double': {'plic': 'ble'},
    'draft': {'draw': 'draf'}, 'ascent': {'scan': 'scen'}, 'drift': {'drive': 'drif'}, 'endeavor': {'deb': 'deav'},
    'greasy': {'crass': 'greas'}, 'garrison': {'ward': 'gar'}, 'stricken': {'strike': 'strick'}, 'nuisance': {'noc': 'nuis'},
    'untold': {'tell': 'told'}, 'varsity': {'uni': '', 'vert': 'vers'}, 'refrain': {'fren': 'frain'},
    'appease': {'pac': 'peas'}, 'pioneer': {'ped': 'pion'}, 'district': {'dis': 'di', 'strict': 'strict'},
    'distress': {'dis': 'di', 'strict': 'stress'}, 'daily': {'day': 'dai'}, 'interval': {'wall': 'val'},
    'nevertheless': {'no': 'ne'}, 'possess': {'sess': 'ess'}, 'possession': {'sess': 'ess'}, 'guild': {'yield': 'guild'},
    'rent': {'dat': 'nt'}, 'rental': {'dat': 'nt'}, 'eternity': {'age': 'etern'}, 'eternal': {'age': 'etern'},
    'lotion': {'lav': 'lot'}, 'comfy': {'fort': 'fy'}, 'manifold': {'many': 'mani'}, 'barn': {'arn': 'rn'},
    'ashore': {'on': 'a'}, 'adultery': {'alter': 'ulter'}, 'curfew': {'cover': 'cur', 'foc': 'few'},
    'enhancement': {'alt': 'han'}, 'enhance': {'alt': 'han'}, 'pragmatic': {'pract': 'prag'}, 'clause': {'clos': 'claus'},
    'sausage': {'sal': 'saus'}, 'sauce': {'sal': 'sauc'}, 'kernel': {'corn': 'kern'}, 'lake': {'lac': 'lak'},
    'cement': {'cid': 'cem'}, 'cuisine': {'cook': 'cuis'}, 'biscuit': {'cook': 'cuit'}, 'culinary': {'cook': 'cul'},
    'parish': {'eco': 'ish'}, 'pixel': {'pict': 'pix'}, 'utmost': {'out': 'ut'}, 'pawn': {'ped': 'pawn'},
    'alignment': {'line': 'lign'}, 'align': {'line': 'lign'}, 'gift': {'give': 'gif'}, 'vintage': {'de': '', 'empt': 'tage'},
    'ambush': {'in': 'am'}, 'pew': {'pod': 'pew'}, 'mermaid': {'mare': 'mer'}, 'diocese': {'eco': 'oces'},
    'neutral': {'neut': 'utr'}, 'demeanor': {'mināre': 'mean'}, 'partake': {'take': 'take'}, 'snack': {'snap': 'snack'},
    'cheat': {'cas': 'eat'}, 'tertiary': {'tri': 'ter'}, 'pointless': {'lose': 'less'}, 'square': {'ex': 's', 'quad': 'quar'},
    'mitigate': {'act': 'gat'}, 'mitigation': {'act': 'gat'}, 'occupancy': {'cap': 'cup'}, 'occupation': {'cap': 'cup'},
    'occupational': {'cap': 'cup'}, 'occupy': {'cap': 'cup'}, 'purchase': {'cap': 'chas'}, 'chase': {'cap': 'chas'},
    'catch': {'cap': 'catch'}, 'catcher': {'cap': 'catch'}, 'catchy': {'cap': 'catch'}, 'cable': {'cap': 'cab'},
    'recover': {'cap': 'cov'}, 'recovery': {'cap': 'cov'}, 'affair': {'fac': 'fair'}, 'fashion': {'fac': 'fash'},
    'fashionable': {'fac': 'fash'}, 'fax': {'fac': 'fa'}, 'feasibility': {'fac': 'feas'}, 'fetish': {'fac': 'fet'},
    'lesson': {'leg': 'less'}, 'anthology': {'leg': 'log'}, 'coil': {'leg': 'il'}, 'endowment': {'dat': 'dow'},
    'dice': {'dat': 'dic'}, 'alloy': {'lig': 'loy'}, 'despise': {'spect': 'spis'}, 'noble': {'not': 'no'},
    'nobility': {'not': 'no'}, 'reconnaissance': {'not': 'naiss'}, 'survey': {'vid': 'vey'}, 'surveyor': {'vid': 'vey'},
    'count': {'com': 'c', 'count': 'ount'}, 'counter': {'com': 'c', 'count': 'ount'},
    'accountable': {'ad': 'ac', 'count': 'count'}, 'account': {'ad': 'ac', 'count': 'count'},
    'accountability': {'ad': 'ac', 'count': 'count'}, 'accountant': {'ad': 'ac', 'count': 'count'},
    'recount': {'com': 'c', 'count': 'ount'}, 'apart': {'ad': 'a', 'part': 'part'}, 'apartment': {'ad': 'a', 'part': 'part'},
    'proof': {'prob': 'proof'}, 'bulletproof': {'prob': 'proof'}, 'waterproof': {'prob': 'proof'},
    'quarry': {'quad': 'quar'}, 'quartet': {'quad': 'quar'}, 'quarter': {'quad': 'quar'}, 'quarterly': {'quad': 'quar'},
    'quarterback': {'quad': 'quar'}, 'round': {'rot': 'round'}, 'roundup': {'rot': 'round'}, 'roundabout': {'rot': 'round'},
    'rodeo': {'rot': 'rod'}, 'sight': {'see': 'sigh'}, 'eyesight': {'see': 'sigh'}, 'insight': {'see': 'sigh'},
    'insightful': {'see': 'sigh'}, 'hindsight': {'see': 'sigh'}, 'oversight': {'see': 'sigh'}, 'safeguard': {'ward': 'guard'},
    'bodyguard': {'ward': 'guard'}, 'disregard': {'ward': 'gard'}, 'regardless': {'ward': 'gard'},
    'strategy': {'ag': 'eg'}, 'strategic': {'ag': 'eg'}, 'strategist': {'ag': 'eg'}, 'strategically': {'ag': 'eg'},
    'mayor': {'magn': 'may'}, 'mayoral': {'magn': 'may'}, 'master': {'magn': 'mas'}, 'mistress': {'magn': 'mis'},
}

# 이웃 조각이 글자를 먼저 가져가 생긴 어긋남을 함께 고친 값(두 번째 검토)
FIX2 = {
    'surgeon': {'surg': 's', 'urg': 'urg'}, 'surgery': {'surg': 's', 'urg': 'urg'}, 'surgical': {'surg': 's', 'urg': 'urg'},
    'allegedly': {'e': 'a', 'leg': 'leg'}, 'steward': {'steward': 'stew', 'ward': 'ard'},
    'stewardship': {'steward': 'stew', 'ward': 'ard'}, 'reverend': {'rever': 'ver'}, 'reverence': {'rever': 'ver'},
    'controller': {'contro': 'cont', 'rol': 'roll'}, 'sheriff': {'riff': 'iff'}, 'stray': {'stra': 's', 'vag': 'tray'},
    'manure': {'manu': 'man', 'oper': 'ur'}, 'obey': {'ob': 'o', 'aud': 'bey'}, 'obedience': {'ob': 'o', 'aud': 'bed'},
    'disobedience': {'ob': 'o', 'aud': 'bed'}, 'amendment': {'e': 'a', 'mend': 'mend'}, 'amend': {'e': 'a', 'mend': 'mend'},
    'dinner': {'di': 'd', 'jun': 'inn'}, 'achievable': {'ac': 'a', 'cap': 'chiev'}, 'achieve': {'ac': 'a', 'cap': 'chiev'},
    'achievement': {'ac': 'a', 'cap': 'chiev'}, 'sewer': {'e': 's', 'aqua': 'ew'}, 'sewage': {'e': 's', 'aqua': 'ew'},
    'scarce': {'e': 's', 'carp': 'carc'}, 'scarcely': {'e': 's', 'carp': 'carc'}, 'nonetheless': {'no': 'n', 'one': 'one'},
    'mitigate': {'mitig': 'miti', 'act': 'gat'}, 'mitigation': {'mitig': 'miti', 'act': 'gat'},
    'cater': {'at': '', 'cap': 'cat'}, 'biopsy': {'bio': 'bi', 'opt': 'ops'},
    'agreeable': {'ag': 'a', 'gree': 'gree'}, 'agree': {'ag': 'a', 'gree': 'gree'}, 'agreement': {'ag': 'a', 'gree': 'gree'},
    'disagree': {'ag': 'a', 'gree': 'gree'}, 'disagreement': {'ag': 'a', 'gree': 'gree'},
    'vantage': {'a': '', 'van': 'vant'}, 'vanguard': {'a': '', 'van': 'van', 'ward': 'guard'},
    'commence': {'en': 'm', 'it': 'enc'}, 'commencement': {'en': 'm', 'it': 'enc'}, 'cinema': {'cine': 'cin', 'graph': 'ema'},
    'ascension': {'as': 'a', 'scan': 'scens'}, 'ascent': {'as': 'a', 'scan': 'scen'}, 'wherever': {'where': 'wher', 'ever': 'ever'},
    'standard': {'stand': 'stan', 'hard': 'dard'}, 'woman': {'wom': 'wo', 'man': 'man'},
    'ancestor': {'anc': 'an', 'ced': 'ces'}, 'ancestral': {'anc': 'an', 'ced': 'ces'}, 'ancestry': {'anc': 'an', 'ced': 'ces'},
    'wilderness': {'wild': 'wil', 'deer': 'der'}, 'entire': {'ir': 'en', 'tir': 'tir'}, 'entirely': {'ir': 'en', 'tir': 'tir'},
    'phosphate': {'phor': 'ph'}, 'anthem': {'ant': 'an', 'phon': 'them'}, 'ambient': {'ambi': 'amb', 'it': 'i'},
    'varsity': {'uni': '', 'vert': 'vars'}, 'eternity': {'age': ''}, 'rescue': {'cuss': 'cu'}, 'stain': {'dis': 's'},
    'stainless': {'dis': 's'}, 'sample': {'empt': 'ampl'}, 'customer': {'com': 'cu', 'suet': 'st'},
    'custom': {'com': 'cu', 'suet': 'st'}, 'square': {'ex': 's', 'squar': 'quar'}, 'evangelical': {'eu': 'ev'},
}
FIX2.update({
    'rescue': {'e': 's', 'cuss': 'cu'}, 'sample': {'e': 's', 'empt': 'ampl'}, 'square': {'e': 's', 'squar': 'quar'},
    'barn': {'bar': 'ba', 'arn': 'rn'}, 'apart': {'ap': 'a', 'part': 'part'}, 'apartment': {'ap': 'a', 'part': 'part'},
    'alignment': {'al': 'a', 'line': 'lign'}, 'align': {'al': 'a', 'line': 'lign'}, 'autopsy': {'auto': 'aut', 'opt': 'ops'},
    'partake': {'part': 'par', 'take': 'take'}, 'cheat': {'e': '', 'cas': 'cheat'}, 'annoy': {'in': 'an', 'annoy': 'noy'},
    'annoyance': {'in': 'an', 'annoy': 'noy'}, 'unavoidable': {'e': 'a', 'void': 'void'}, 'avoidance': {'e': 'a', 'void': 'void'},
    'issue': {'e': 'i', 'iss': 'ssu'}, 'issuance': {'e': 'i', 'iss': 'ssu'}, 'lord': {'lord': 'lor', 'ward': 'd'},
    'lady': {'lady': 'la', 'dy': 'dy'}, 'kaleidoscope': {'kaleido': 'kal', 'eido': 'eido'},
})
for _w, _m in FIX2.items():
    OVERRIDES.setdefault(_w, {}).update(_m)
for _w in ('count', 'counter', 'recount', 'accountable', 'account', 'accountability', 'accountant'):
    OVERRIDES.pop(_w, None)  # co + unt 이 맞다(computare = com + putare)


def _sim(a, b):
    return difflib.SequenceMatcher(None, a, b, autojunk=False).ratio()


def _fuzzy(seg, f, prefix):
    best = None
    for L in range(1, min(len(seg), len(f) + 3) + 1):
        for i in ([0] if prefix else range(0, len(seg) - L + 1)):
            s = seg[i:i + L]
            r = _sim(s, f) + (0.25 if s[0] == f[0] else 0.0) - 0.015 * i
            if best is None or r > best[0] + 1e-9:
                best = (r, i, L)
    return best


def fit(word, etym):
    """etym의 form을 단어 철자에 맞춘다. 새 목록을 돌려준다(원래 목록은 그대로)."""
    low = word.lower()
    ov = OVERRIDES.get(word, {})
    items = [dict(e) for e in etym]
    want = []  # 찾을 글자(사람이 정한 값이 먼저)
    for e in items:
        f = str(e.get('form', ''))
        want.append(ov[f].lower() if f in ov else f.lower())
    spans = [None] * len(items)
    pos = 0
    for k, f in enumerate(want):
        if not f:
            continue
        at = low.find(f, pos)
        if at >= 0:
            spans[k] = (at, at + len(f)); pos = at + len(f)
    for k, e in enumerate(items):
        f0 = str(e.get('form', ''))
        if spans[k] is None and want[k] and f0:
            lo = next((spans[j][1] for j in range(k - 1, -1, -1) if spans[j]), 0)
            hi = next((spans[j][0] for j in range(k + 1, len(items)) if spans[j]), len(low))
            seg = low[lo:hi] if hi > lo else ''
            if seg:
                prefix = str(e.get('root', '')).endswith('-') or (k == 0 and lo == 0 and len(items) > 1)
                got = None
                for v in VARIANTS.get(str(e.get('root', '')), []):
                    i = seg.find(v)
                    if i >= 0 and (not prefix or i == 0):
                        got = (i, len(v)); break
                if got is None:
                    b = _fuzzy(seg, want[k], prefix)
                    if b:
                        got = (b[1], b[2])
                if got:
                    spans[k] = (lo + got[0], lo + got[0] + got[1])
    for k, e in enumerate(items):
        f0 = str(e.get('form', ''))
        if spans[k] is None:
            if f0:
                e['base'] = f0
                e['form'] = ''
                e['lost'] = True
            continue
        text = word[spans[k][0]:spans[k][1]]
        if text.lower() != f0.lower():
            e['base'] = f0
        e['form'] = text
        e['at'] = spans[k][0]
    return items
