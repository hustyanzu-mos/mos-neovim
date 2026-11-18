<template>
  <div>
    <h2 class="mb-4">Neovim</h2>

    <v-skeleton-loader v-if="loading" :loading="true" type="card" />

    <div v-else style="margin-bottom: 80px">
      <v-alert v-if="error" type="error" variant="tonal" closable class="mb-4" @click:close="error = ''">
        {{ error }}
      </v-alert>

      <v-card class="mb-4 pa-0">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2">mdi-pencil-box-outline</v-icon>
          <span>Status</span>
          <v-spacer />
          <v-chip :color="status.installed ? 'success' : 'grey'" size="small" variant="tonal">
            {{ status.installed ? 'Installed' : 'Not installed' }}
          </v-chip>
        </v-card-title>
        <v-card-text>
          <v-row>
            <v-col cols="12" md="3">
              <div class="text-caption text-medium-emphasis">Installed</div>
              <div class="text-subtitle-1 font-weight-medium">{{ status.version || 'Not installed' }}</div>
            </v-col>
            <v-col cols="12" md="3">
              <div class="text-caption text-medium-emphasis">Latest</div>
              <div class="text-subtitle-1 font-weight-medium">{{ latestVersion || '-' }}</div>
            </v-col>
            <v-col cols="12" md="3">
              <div class="text-caption text-medium-emphasis">Command</div>
              <div class="text-subtitle-1 font-weight-medium"><code>nvim</code></div>
            </v-col>
            <v-col cols="12" md="3">
              <div class="text-caption text-medium-emphasis">Runtime</div>
              <div class="text-caption">{{ status.runtime || '-' }}</div>
            </v-col>
          </v-row>

          <div class="d-flex flex-wrap ga-2 mt-4">
            <v-btn size="small" variant="tonal" color="secondary" :loading="checking" @click="checkForUpdates">
              Check updates
            </v-btn>
            <v-btn v-if="!status.installed" size="small" color="primary" :loading="installing" @click="installCore">
              Install
            </v-btn>
            <v-btn v-else-if="updateAvailable" size="small" color="primary" :loading="updating" @click="updateCore">
              Update to {{ latestVersion }}
            </v-btn>
            <v-btn size="small" variant="text" @click="refreshAll">Refresh</v-btn>
          </div>
        </v-card-text>
      </v-card>

      <v-card class="mb-4 pa-0">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2">mdi-file-cog-outline</v-icon>
          <span>Configuration</span>
        </v-card-title>
        <v-card-text>
          <v-text-field :model-value="status.config" label="init.lua" readonly density="compact" variant="outlined" hide-details>
            <template #append-inner>
              <v-btn icon="mdi-content-copy" size="small" variant="text" @click="copy(status.config)" />
            </template>
          </v-text-field>
          <p class="text-body-2 text-medium-emphasis mt-3">
            The config directory is persistent. Edit <code>init.lua</code> through SSH or the MOS Filebrowser.
            Plugins and undo history also live under the plugin directory.
          </p>
          <v-btn size="small" variant="tonal" class="mt-3" :loading="creatingConfig" @click="createConfig">
            Create default init.lua
          </v-btn>
        </v-card-text>
      </v-card>

      <v-card class="pa-0">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2">mdi-terminal</v-icon>
          <span>Use</span>
        </v-card-title>
        <v-card-text>
          <p class="text-body-2 mb-2">Open a terminal on MOS or over SSH and run:</p>
          <pre class="neovim-code">nvim
nvim /mnt/cache/some-file.txt</pre>
          <p class="text-caption text-medium-emphasis mt-2">
            The wrapper sets XDG config/data/state/cache to the persistent plugin directory.
          </p>
        </v-card-text>
      </v-card>
    </div>

    <v-snackbar v-model="snackbar" :color="snackbarColor" timeout="4000">{{ snackbarText }}</v-snackbar>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue';

const PLUGIN_NAME = 'neovim';
const DEFAULT_SETTINGS = { auto_install: true, pin_version: '', version: '' };

const loading = ref(true);
const checking = ref(false);
const installing = ref(false);
const updating = ref(false);
const creatingConfig = ref(false);
const error = ref('');
const snackbar = ref(false);
const snackbarText = ref('');
const snackbarColor = ref('success');

const settings = reactive({ ...DEFAULT_SETTINGS });
const status = reactive({ installed: false, version: '', config: '', runtime: '', command: 'nvim' });
const latestVersion = ref('');
const updateAvailable = ref(false);

const authHeaders = () => ({ Authorization: 'Bearer ' + (localStorage.getItem('authToken') || '') });
const jsonHeaders = () => ({ ...authHeaders(), 'Content-Type': 'application/json' });

function notify(text, color = 'success') {
  snackbarText.value = text;
  snackbarColor.value = color;
  snackbar.value = true;
}

function setError(e) {
  error.value = e instanceof Error ? e.message : String(e);
  notify(error.value, 'error');
}

function parseOutput(data) {
  let output = data?.output;
  if (typeof output === 'string') {
    try { output = JSON.parse(output); } catch { /* keep string */ }
  }
  return output;
}

async function query(args, parseJson = false, timeout = 60) {
  const res = await fetch('/api/v1/mos/plugins/query', {
    method: 'POST',
    headers: jsonHeaders(),
    body: JSON.stringify({ command: PLUGIN_NAME, args, timeout, parse_json: parseJson }),
  });
  if (!res.ok) throw new Error(`Plugin query failed: HTTP ${res.status}`);
  const data = await res.json();
  if (data && data.success === false) throw new Error(data.error || data.message || 'Plugin query failed');
  return data;
}

async function fetchSettings() {
  const res = await fetch(`/api/v1/mos/plugins/settings/${PLUGIN_NAME}`, { headers: authHeaders() });
  if (!res.ok) throw new Error(`Settings request failed: HTTP ${res.status}`);
  const raw = await res.json();
  const data = raw && raw.data && typeof raw.data === 'object' ? raw.data : raw;
  for (const key of Object.keys(DEFAULT_SETTINGS)) {
    if (data[key] !== undefined && data[key] !== null) settings[key] = data[key];
  }
}

async function refreshStatus() {
  const data = await query(['status'], true, 10);
  const out = parseOutput(data) || {};
  status.installed = out.installed === true;
  status.version = out.version || '';
  status.config = out.config || '';
  status.runtime = out.runtime || '';
  status.command = out.command || 'nvim';
  if (out.version && out.version !== 'not installed') settings.version = out.version;
}

async function checkForUpdates() {
  checking.value = true;
  try {
    const data = await query(['check_version'], true, 30);
    const out = parseOutput(data) || {};
    latestVersion.value = out.latest || '';
    updateAvailable.value = status.installed && out.update_available === true;
  } catch (e) {
    setError(e);
  } finally {
    checking.value = false;
  }
}

async function refreshAll() {
  loading.value = true;
  try {
    await fetchSettings();
    await refreshStatus();
    await checkForUpdates();
  } catch (e) {
    setError(e);
  } finally {
    loading.value = false;
  }
}

async function installCore() {
  installing.value = true;
  try {
    await query(['install_binary', 'latest'], false, 180);
    await fetchSettings();
    await refreshStatus();
    await checkForUpdates();
    notify('Neovim installed');
  } catch (e) {
    setError(e);
  } finally {
    installing.value = false;
  }
}

async function updateCore() {
  updating.value = true;
  try {
    await query(['install_binary', 'latest'], false, 180);
    await fetchSettings();
    await refreshStatus();
    await checkForUpdates();
    notify('Neovim updated');
  } catch (e) {
    setError(e);
  } finally {
    updating.value = false;
  }
}

async function createConfig() {
  creatingConfig.value = true;
  try {
    await query(['init_config'], false, 10);
    await refreshStatus();
    notify('Default init.lua created');
  } catch (e) {
    setError(e);
  } finally {
    creatingConfig.value = false;
  }
}

async function copy(text) {
  try {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(text);
    } else {
      const area = document.createElement('textarea');
      area.value = text;
      document.body.appendChild(area);
      area.select();
      document.execCommand('copy');
      document.body.removeChild(area);
    }
    notify('Copied');
  } catch {
    notify('Copy failed', 'error');
  }
}

onMounted(async () => {
  await refreshAll();
});
</script>

<style scoped>
.neovim-code {
  background: rgba(0, 0, 0, 0.25);
  padding: 12px;
  border-radius: 8px;
  font-size: 12px;
  line-height: 1.4;
}
</style>