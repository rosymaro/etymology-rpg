class_name EffectRegistry
extends RefCounted
## 데이터의 "class" 이름으로 효과 객체를 만든다(architecture.md 5절). 새 효과는 여기에 한 줄 더한다.

static func _skills() -> Dictionary:
	return {
		"StatBonus": StatBonusSkill,
		"EnemyStatMod": EnemyStatModSkill,
		"UnknownEnemyAtk": UnknownEnemyAtkSkill,
		"LowHpEnemyAtk": LowHpEnemyAtkSkill,
		"RerollNext": RerollNextSkill,
		"CopyEnemySkill": CopyEnemySkill,
		"RecastMagic": RecastMagicSkill,
		"DamageReduce": DamageReduceSkill,
		"DirectDamage": DirectDamageSkill,
		"FirstStrike": FirstStrikeSkill,
		"DoubleFirstRound": DoubleFirstRoundSkill,
		"NoSkillHeal": NoSkillHealSkill,
	}

static func _magics() -> Dictionary:
	return {
		"StrikeFirst": StrikeFirstMagic,
		"StrikeUndo": StrikeUndoMagic,
		"StrikeSilence": StrikeSilenceMagic,
		"StrikeReflect": StrikeReflectMagic,
		"CoinBias": CoinBiasMagic,
		"HalveAttack": HalveAttackMagic,
		"SwapToBack": SwapToBackMagic,
		"PullFromBack": PullFromBackMagic,
		"PoolToFirst": PoolToFirstMagic,
		"ShareDamage": ShareDamageMagic,
		"HealNow": HealNowMagic,
		"Shield": ShieldMagic,
		"FirstStrikeNow": FirstStrikeNowMagic,
		"DamageWall": DamageWallMagic,
	}

static func _boss() -> Dictionary:
	return {
		"CoinLock": CoinLockAbility,
		"LevelGate": LevelGateAbility,
	}


static func skill_implemented(def: Dictionary) -> bool:
	return _skills().has(def.get("class", ""))


static func make_skill(root: String, def: Dictionary, cond_tier: String = "보통") -> Skill:
	if not skill_implemented(def):
		return null
	var s: Skill = _skills()[def["class"]].new()
	s.configure(root, def.get("params", {}), cond_tier)
	return s


static func magic_implemented(def: Dictionary) -> bool:
	return _magics().has(def.get("class", ""))


static func make_magic(def: Dictionary) -> BattleMagic:
	if not magic_implemented(def):
		return null
	var m: BattleMagic = _magics()[def["class"]].new()
	m.configure(def)
	return m


static func make_boss(def: Dictionary) -> BossAbility:
	if not _boss().has(def.get("class", "")):
		return null
	var b: BossAbility = _boss()[def["class"]].new()
	b.configure(def.get("params", {}))
	return b
