#include <amxmodx>
#include <nvault>
#include <time>
#include "include/custom_player_models.inc"

#define MAX_AUTHID_LENGTH 64

new const CLCMDS[][] = {
	"say /models",
	"say_team /models"
};

#define DEFAULT_STATE true

#define ANTISPAM_DELAY 1.0

#define PRUNE_DAYS 30

#define VAULT_NAME "custom_player_models"

new g_Vault = INVALID_HANDLE;

public plugin_init() {
	register_plugin("Custom Player Models Toggle", "0.2.1", "BlackSignature");
	register_dictionary("cpm_toggle.txt");

	for(new i; i < sizeof(CLCMDS); i++) {
		register_clcmd(CLCMDS[i], "ClCmd_Toggle");
	}
}

public plugin_cfg() {
	g_Vault = nvault_open(VAULT_NAME);

	if(g_Vault != INVALID_HANDLE) {
		nvault_prune(g_Vault, 0, get_systime() - (PRUNE_DAYS * SECONDS_IN_DAY));
	}
}

public client_authorized(id, const authid[]) {
	if(is_user_connected(id)) {
		load_player(id, authid);
	}
}

public client_putinserver(id) {
	new authid[MAX_AUTHID_LENGTH];

	if(get_user_authid(id, authid, charsmax(authid))) {
		load_player(id, authid);
	}
}

load_player(id, const authid[]) {
	if (is_user_bot(id) || is_user_hltv(id)) {
		return;
	}
	if(g_Vault != INVALID_HANDLE && nvault_get(g_Vault, authid)) {
		custom_player_models_enable(id, !DEFAULT_STATE);
		nvault_touch(g_Vault, authid);
	} else {
		custom_player_models_enable(id, DEFAULT_STATE);
	}
}

public ClCmd_Toggle(id) {
	static Float:fNextTime[MAX_PLAYERS + 1]

	new Float:fGameTime = get_gametime();

	if(fNextTime[id] > fGameTime) {
		return PLUGIN_HANDLED;
	}

	fNextTime[id] = fGameTime + ANTISPAM_DELAY;

	new bool:bEnabled = custom_player_models_is_enable(id);
	custom_player_models_enable(id, !bEnabled);

	client_print_color(id, print_team_red, "%L", id, bEnabled ? "CPM__TOGGLE_OFF" : "CPM__TOGGLE_ON");

	if(g_Vault == INVALID_HANDLE) {
		return PLUGIN_HANDLED;
	}

	new authid[MAX_AUTHID_LENGTH];
	get_user_authid(id, authid, charsmax(authid));

	if(bEnabled) {
		nvault_set(g_Vault, authid, "1");
	} else {
		nvault_remove(g_Vault, authid);
	}

	return PLUGIN_HANDLED;
}

public plugin_end() {
	if(g_Vault != INVALID_HANDLE) {
		nvault_close(g_Vault);
	}
}