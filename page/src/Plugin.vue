<template>
  <div>
    <h2 class="mb-4">Neovim</h2>

    <v-skeleton-loader v-if="loading" :loading="true" type="card" />

    <div v-else style="margin-bottom: 80px">
      <v-alert v-if="error" type="error" variant="tonal" closable class="mb-4" @click:close="error = ''">
        {{ error }}
      </v-alert>

      <v-alert v-if="status.storage_mode === 'memory'" type="warning" variant="tonal" class="mb-4">
        <div class="font-weight-medium">Using RAM instead of a pool</div>
        <div class="text-body-2 mt-1">
          No writable pool was detected, or the configured path is under /run. Config and data will be lost on reboot.
          Set a pool path such as /mnt/cache/appdata/neovim below.
        </div>
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
              <div class="text-caption text-medium-emphasis">Version</div>
              <div class="text-subtitle-1 font-weight-medium">{{ status.version || 'Not installed' }}</div>
            </v-col>
            <v-col cols="12" md="3">
              <div class="text-caption text-medium-emphasis">Command</div>
              <div class="text-subtitle-1 font-weight-medium"><code>nvim</code></div>
            </v-col>
            <v-col cols="12" md="3">
              <div class="text-caption text-medium-emphasis">Storage</div>
              <v-chip
                size="small"
                :color="status.storage_mode === 'persistent' ? 'success' : 'warning'"
                variant="tonal"
              >
                {{ status.storage_mode === 'persistent' ? 'Pool' : 'RAM' }}
              </v-chip>
            </v-col>
            <v-col cols="12" md="3">
              <div class="text-caption text-medium-emphasis">Pool</div>
              <div class="text-body-2">{{ status.pool_root || 'Not detected' }}</div>
            </v-col>
          </v-row>
          <div class="d-flex flex-wrap ga-2 mt-4">
            <v-btn size="small" variant="text" @click="refreshAll">Refresh</v-btn>
          </div>
          <p class="text-caption text-medium-emphasis mt-2">
            Updates come through the MOS Hub plugin release.
          </p>
        </v-card-text>
      </v-card>

      <v-card class="pa-0">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2">mdi-file-cog-outline</v-icon>
          <span>Configuration</span>
        </v-card-title>
        <v-card-text>
          <v-text-field
            v-model="form.config_dir"
            label="Config directory"
            hint="Empty uses the auto-detected pool path. This is the XDG root that contains nvim/init.lua."
            persistent-hint
            density="compact"
            variant="outlined"
            class="mb-4"
          />
          <v-text-field
            v-model="form.data_dir"
            label="Data directory"
            hint="Empty uses the auto-detected pool path. Use /run/neovim/data only if you explicitly want RAM."
            persistent-hint
            density="compact"
            variant="outlined"
            class="mb-4"
          />

          <v-row class="mb-2">
            <v-col cols="12" md="6">
              <div class="text-caption text-medium-emphasis">Current config root</div>
              <div class="text-body-2">{{ status.config_root || '-' }}</div>
              <v-chip
                size="x-small"
                :color="status.config_mode === 'persistent' ? 'success' : 'warning'"
                variant="tonal"
                class="mt-1"
              >
                {{ status.config_mode === 'persistent' ? 'Persistent' : 'RAM' }}
              </v-chip>
            </v-col>
            <v-col cols="12" md="6">
              <div class="text-caption text-medium-emphasis">Current data root</div>
              <div class="text-body-2">{{ status.data_root || '-' }}</div>
              <v-chip
                size="x-small"
                :color="status.data_mode === 'persistent' ? 'success' : 'warning'"
                variant="tonal"
                class="mt-1"
              >
                {{ status.data_mode === 'persistent' ? 'Persistent' : 'RAM' }}
              </v-chip>
            </v-col>
          </v-row>

          <p class="text-body-2 text-medium-emphasis mt-2">
            State and cache stay in <code>/run/neovim</code> and are cleared on reboot.
            Config and data are kept on the pool and are not removed by plugin uninstall.
          </p>

          <div class="d-flex flex-wrap ga-2 mt-4">
            <v-btn size="small" color="primary" :loading="saving" @click="saveSettings">
              <v-icon start>mdi-content-save</v-icon>
              Save settings
            </v-btn>
            <v-btn size="small" variant="text" @click="usePoolDefaults">Use pool defaults</v-btn>
            <v-btn size="small" variant="text" @click="useRamData">Use RAM for data</v-btn>
          </div>

          <v-divider class="my-4" />

          <v-text-field :model-value="status.config" label="init.lua" readonly density="compact" variant="outlined" hide-details>
            <template #append-inner>
              <v-btn icon="mdi-content-copy" size="small" variant="text" @click="copy(status.config)" />
            </template>
          </v-text-field>
          <v-btn size="small" variant="tonal" class="mt-3" :loading="creatingConfig" @click="createConfig">
            Create default init.lua
          </v-btn>
        </v-card-text>
      </v-card>
    </div>

    <v-snackbar v-model="snackbar" :color="snackbarColor" timeout="4000">{{ snackbarText }}</v-snackbar>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue';

const PLUGIN_NAME = 'neovim';
const DEFAULT_SETTINGS = { config_dir: '', data_dir: '' };

const loading = ref(true);
const saving = ref(false);
const creatingConfig = ref(false);
const error = ref('');
const snackbar = ref(false);
const snackbarText = ref('');
const snackbarColor = ref('success');

const settings = reactive({ ...DEFAULT_SETTINGS });
const form = reactive({ config_dir: '', data_dir: '' });
const status = reactive({
  installed: false,
  version: '',
  config: '',
  config_root: '',
  data: '',
  data_root: '',
  data_mode: 'memory',
  config_mode: 'memory',
  storage_mode: 'memory',
  pool_root: '',
  config_exists: false,
  runtime: '',
  plugin_dir: '',
  release: '',
  state_root: '',
  cache_root: '',
  command: 'nvim',
});

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
  form.config_dir = settings.config_dir || '';
  form.data_dir = settings.data_dir || '';
}

async function refreshStatus() {
  const data = await query(['status'], true, 10);
  const out = parseOutput(data) || {};
  status.installed = out.installed === true;
  status.version = out.version || '';
  status.config = out.config || '';
  status.config_root = out.config_root || '';
  status.data = out.data || '';
  status.data_root = out.data_root || '';
  status.data_mode = out.data_mode || 'memory';
  status.config_mode = out.config_mode || 'memory';
  status.storage_mode = out.storage_mode || 'memory';
  status.pool_root = out.pool_root || '';
  status.config_exists = out.config_exists === true;
  status.runtime = out.runtime || '';
  status.plugin_dir = out.plugin_dir || '';
  status.release = out.release || '';
  status.state_root = out.state_root || '';
  status.cache_root = out.cache_root || '';
  status.command = out.command || 'nvim';
}

async function refreshAll() {
  loading.value = true;
  try {
    await fetchSettings();
    await refreshStatus();
  } catch (e) {
    setError(e);
  } finally {
    loading.value = false;
  }
}

function usePoolDefaults() {
  form.config_dir = '';
  form.data_dir = '';
  notify('Pool defaults selected; click Save settings');
}

function useRamData() {
  form.data_dir = '/run/neovim/data';
  notify('RAM data selected; click Save settings');
}

function validatePath(label, value) {
  if (!value) return;
  if (!value.startsWith('/')) {
    throw new Error(`${label} must be an absolute path`);
  }
  const reserved = [status.plugin_dir, status.release, status.state_root, status.cache_root]
    .filter(Boolean);
  if (reserved.some((p) => value === p || value.startsWith(p + '/'))) {
    throw new Error(`${label} must be outside the plugin and runtime directories`);
  }
  if (value === '/boot' || value.startsWith('/boot/')) {
    throw new Error(`${label} must be on a pool such as /mnt/cache/appdata/neovim, not /boot`);
  }
  if (!value.startsWith('/mnt/') && value !== '/run' && !value.startsWith('/run/') && value !== '/tmp' && !value.startsWith('/tmp/')) {
    throw new Error(`${label} must be under /mnt, /run, or /tmp`);
  }
}

async function saveSettings() {
  saving.value = true;
  try {
    const configDir = form.config_dir.trim();
    const dataDir = form.data_dir.trim();
    validatePath('Config directory', configDir);
    validatePath('Data directory', dataDir);
    if (configDir && dataDir && configDir === dataDir) {
      throw new Error('Config and data directories must be different');
    }

    const res = await fetch(`/api/v1/mos/plugins/settings/${PLUGIN_NAME}`, {
      method: 'POST',
      headers: jsonHeaders(),
      body: JSON.stringify({ config_dir: configDir, data_dir: dataDir }),
    });
    if (!res.ok) throw new Error(`Save failed: HTTP ${res.status}`);
    settings.config_dir = configDir;
    settings.data_dir = dataDir;
    await refreshStatus();
    notify('Settings saved');
  } catch (e) {
    setError(e);
  } finally {
    saving.value = false;
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