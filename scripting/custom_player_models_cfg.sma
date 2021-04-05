#include <amxmodx>
#include <reapi>
#include "include/custom_player_models.inc"

// Steam (flag '@') support, comment if you run steam-only server
#define STEAM_SUPPORT

// Config filename in 'amxmodx/configs'
#define CONFIG_FILENAME "custom_player_models.ini"
//#define CONFIG_FILENAME "custom_player_models/models.ini"

//#define DEBUG

#define MAX_AUTHID_LENGTH 64

enum _:access_s {
	ACCESS_AUTH[MAX_AUTHID_LENGTH],
	ACCESS_KEY[CPM_MAX_MODEL_LENGTH]
};

new Array:g_Models = Invalid_Array, g_Size;

public plugin_init() {
	register_plugin("Custom Player Models CFG", "0.2.2", "BlackSignature");

	RegisterHookChain(RG_CBasePlayer_GetIntoGame, "CBasePlayer_GetIntoGame_Post", true);
	RegisterHookChain(RG_CBasePlayer_SetClientUserInfoName, "CBasePlayer_SetClientUserInfoName_Post", true);

#if defined DEBUG
	register_clcmd("radio2", "CmdRadio2");
	register_clcmd("radio3", "CmdRadio3");
#endif
}

public custom_player_models_init() {
	new path[128];
	new len = get_localinfo("amxx_configsdir", path, charsmax(path));
	formatex(path[len], charsmax(path) - len, "/%s", CONFIG_FILENAME);
	new file = fopen(path, "rt");
	if (!file) {
		set_fail_state("Can't %s '%s'", file_exists(path) ? "read" : "find", path);
		return;
	}

	g_Models = ArrayCreate(access_s);

	new line[256], data[access_s], model_tt[64], body_tt[6], model_ct[64], body_ct[6], time[32];

	new systime = get_systime();

	while (!feof(file)) {
		fgets(file, line, charsmax(line));
		if (line[0] == EOS || line[0] == ';') {
			continue;
		}

		if (parse(line,
			data[ACCESS_AUTH], charsmax(data[ACCESS_AUTH]),
			data[ACCESS_KEY], charsmax(data[ACCESS_KEY]),
			model_tt, charsmax(model_tt),
			body_tt, charsmax(body_tt),
			model_ct, charsmax(model_ct),
			body_ct, charsmax(body_ct),
			time, charsmax(time)
		) != 7) {
			continue;
		}

		custom_player_models_register(data[ACCESS_KEY], model_tt, str_to_num(body_tt), model_ct, str_to_num(body_ct));

		if(data[ACCESS_AUTH][0] == EOS) {
			continue;
		}

	#if !defined STEAM_SUPPORT
		if(data[ACCESS_AUTH][0] == '@') {
			continue;
		}
	#endif

		if(time[0] && systime >= parse_time(time, "%d.%m.%Y %H:%M")) {
			continue
		}

		ArrayPushArray(g_Models, data);
	}

	fclose(file);

	g_Size = ArraySize(g_Models);
}

public CBasePlayer_GetIntoGame_Post(const id) {
	if(is_user_hltv(id)) {
		return;
	}

	// for client_putinserver()
	// redundant here? not sure about it
	if(is_user_bot(id) && !is_entity(id)) {
		RequestFrame("fix_bot", get_user_userid(id));
		return;
	}

	set_load_player(id);
}

public CBasePlayer_SetClientUserInfoName_Post(const id, const infobuffer[], const new_name[]) {
	RequestFrame("name_delay", id);
}

public name_delay(const id) {
	if(is_user_alive(id) && is_entity(id)) { // is_entity() as botfix, can be redundant
		set_load_player(id);
	}
}

set_load_player(const id) {
	new authid[MAX_AUTHID_LENGTH];
	if(get_user_authid(id, authid, charsmax(authid))) {
		load_player(id, authid);
	}
}

public fix_bot(const userid) {
	new id = find_player("k", userid);

	if(id) {
		load_player(id, "BOT");
	}
}

load_player(id, const authid[]) {
	new i, data[access_s], player_flags = get_user_flags(id);

	new szName[MAX_NAME_LENGTH];
	get_user_name(id, szName, charsmax(szName));

	for( ; i < g_Size; i++) {
		ArrayGetArray(g_Models, i, data);

		switch(data[ACCESS_AUTH][0]) {
			case '*': {
				break;
			}
		#if defined STEAM_SUPPORT
			case '@': {
				if(is_user_steam(id)) {
					break;
				}
		#endif
			}
			case 'S', 'V': {
				if(strcmp(authid, data[ACCESS_AUTH], .ignorecase = true) == 0) {
					break;
				}
			}
			case '#': {
				if(strcmp(szName, data[ACCESS_AUTH][1], .ignorecase = true) == 0) {
					break;
				}
			}
			default: {
				if(player_flags & read_flags(data[ACCESS_AUTH])) {
					break;
				}
			}
		}
	}

	new szKey[CPM_MAX_MODEL_LENGTH];
	new bool:bHas = custom_player_models_has(id, szKey, charsmax(szKey));

	if(i != g_Size) {
		if(!bHas || strcmp(szKey, data[ACCESS_KEY], .ignorecase = false) != 0) {
			custom_player_models_set(id, data[ACCESS_KEY]);
		}
	} else if(bHas) {
		custom_player_models_reset(id);
	}
}

public plugin_end() {
	if(g_Models != Invalid_Array) {
		ArrayDestroy(g_Models);
	}
}

#if defined DEBUG
	public CmdRadio2(const id) {
		if (custom_player_models_is_enable(id)) {
			client_print_color(id, print_team_grey, "^4Models ^3disabled");
			custom_player_models_enable(id, false);
		} else {
			client_print_color(id, print_team_blue, "^4Models ^3enabled");
			custom_player_models_enable(id, true);
		}
		return PLUGIN_HANDLED;
	}

	public CmdRadio3(const id) {
		new player;
		get_user_aiming(id, player);
		if (!is_user_connected(player)) {
			client_print_color(id, print_team_red, "^3Player not found");
			return PLUGIN_HANDLED;
		}

		if (custom_player_models_has(player)) {
			client_print_color(id, print_team_grey, "^4Model ^3reseted");
			custom_player_models_reset(player);
		} else {
			new data[access_s];
			ArrayGetArray(g_Models, random_num(0, g_Size - 1), data);
			custom_player_models_set(player, data[ACCESS_KEY]);
			client_print_color(id, print_team_blue, "^4Model ^3setted ^4[%s]", data[ACCESS_KEY]);
		}
		return PLUGIN_HANDLED;
	}
#endif
