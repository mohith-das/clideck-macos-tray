const { join } = require('path');
const { readFileSync } = require('fs');
const { exec } = require('child_process');
const SysTray = require('systray').default;
const notifier = require('node-notifier');

module.exports = {
  init(api) {
    api.log('Starting init');
    let systray = null;
    let trayReady = false;
    let sessions = new Map();
    let statuses = new Map();
    let enabled = api.getSetting('enabled') ?? true;
    let clideckPort = 4000;
    
    // Attempt to read the port from CliDeck config
    try {
      const cfgPath = join(require('os').homedir(), '.clideck', 'settings.json');
      const cfg = JSON.parse(readFileSync(cfgPath, 'utf8'));
      if (cfg.port) clideckPort = cfg.port;
    } catch(e) {}
    
    // Listen for config changes to update the port dynamically
    api.onConfigChange?.((cfg) => {
      if (cfg && cfg.port) clideckPort = cfg.port;
    });

    let iconData = '';
    try {
      iconData = readFileSync(join(__dirname, 'tray-icon.png')).toString('base64');
      api.log('Loaded icon, base64 length: ' + iconData.length);
    } catch (e) {
      api.log('Warning: Could not load tray-icon.png');
    }

    function buildMenu() {
      const items = [];
      
      items.push({
        title: "Open Dashboard",
        tooltip: `Open CliDeck (Port ${clideckPort})`,
        checked: false,
        enabled: true
      });
      
      items.push({
        title: "---",
        tooltip: "",
        checked: false,
        enabled: false
      });

      if (sessions.size === 0) {
        items.push({
          title: "No active agents",
          tooltip: "",
          checked: false,
          enabled: false
        });
      } else {
        const sorted = Array.from(sessions.values()).sort((a, b) => {
          if (a.projectId !== b.projectId) return (a.projectId || '').localeCompare(b.projectId || '');
          return (a.name || '').localeCompare(b.name || '');
        });

        for (const s of sorted) {
          const isWorking = statuses.get(s.id) || false;
          const statusIcon = isWorking ? "🟢" : "⚪";
          const statusText = isWorking ? "Working" : "Idle";
          const projectName = s.projectId ? `[${s.projectId.slice(0,6)}] ` : '';
          
          items.push({
            title: `${statusIcon} ${projectName}${s.name || s.presetId} (${statusText})`,
            tooltip: "Click to open dashboard",
            checked: false,
            enabled: true,
          });
        }
      }

      items.push({
        title: "---",
        tooltip: "",
        checked: false,
        enabled: false
      });

      items.push({
        title: "Quit CliDeck",
        tooltip: "Stop the CliDeck server",
        checked: false,
        enabled: true
      });

      return {
        icon: iconData,
        title: " ", // Single space instead of empty string so macOS renders it
        tooltip: "CliDeck",
        items: items
      };
    }

    function updateTray() {
      if (!enabled || !systray || !trayReady) return;
      try {
        systray.sendAction({
          type: 'update-menu',
          menu: buildMenu()
        });
      } catch (e) {
        api.log('Failed to update tray: ' + e.message);
      }
    }

    function initTray() {
      api.log('Calling initTray');
      if (systray) return;
      
      const menu = buildMenu();
      api.log('Building menu, icon length: ' + (menu.icon ? menu.icon.length : 0));
      systray = new SysTray({
        menu,
        debug: false,
        copyDir: true
      });

      systray.onReady(() => {
        api.log('systray is ready!');
        trayReady = true;
        setTimeout(() => updateTray(), 500); // Give the Go binary a moment
      });

      systray.onClick(action => {
        const title = action.item.title;
        if (title === "Open Dashboard" || title.includes("🟢") || title.includes("⚪")) {
          const cmd = process.platform === 'win32' ? `start http://localhost:${clideckPort}` :
                      process.platform === 'darwin' ? `open http://localhost:${clideckPort}` :
                      `xdg-open http://localhost:${clideckPort}`;
          exec(cmd);
        } else if (title === "Quit CliDeck") {
          api.log('Quit requested from tray');
          systray.kill(false);
          setTimeout(() => process.exit(0), 500);
        }
      });

      // trayReady = true; is now in onReady
      // updateTray(); is now in onReady
    }

    function killTray() {
      if (systray) {
        systray.kill(false);
        systray = null;
        trayReady = false;
      }
    }

    if (enabled) {
      initTray();
    }

    function syncSessions() {
      try {
        let allSessions = [];
        let allStatuses = new Map();

        // 1. Load active sessions from API
        const active = api.getSessions() || [];
        require('fs').writeFileSync('/Users/mohithdas/.clideck/plugins/macos-tray/debug_active.json', JSON.stringify(active, null, 2));
        
        const activeIds = new Set();
        for (const s of active) {
          activeIds.add(s.id);
          allSessions.push(s);
          allStatuses.set(s.id, s.working || false);
        }

        // 2. Load resumable/idle sessions from sessions.json
        try {
          const sessionsPath = join(require('os').homedir(), '.clideck', 'sessions.json');
          if (require('fs').existsSync(sessionsPath)) {
            const resumable = JSON.parse(require('fs').readFileSync(sessionsPath, 'utf8'));
            if (Array.isArray(resumable)) {
              for (const rs of resumable) {
                if (!activeIds.has(rs.id)) {
                  allSessions.push({
                    id: rs.id,
                    name: rs.name,
                    projectId: rs.projectId,
                    presetId: rs.presetId || 'shell',
                    working: false
                  });
                  allStatuses.set(rs.id, false);
                }
              }
            }
          }
        } catch (e) {
          api.log(`[syncSessions] Failed to read sessions.json: ${e.message}`);
        }

        let changed = false;
        
        // Check for new or updated sessions
        for (const s of allSessions) {
          if (!sessions.has(s.id)) {
            sessions.set(s.id, s);
            statuses.set(s.id, s.working || false);
            changed = true;
          } else {
            // Check if name, project, or working state changed
            const existing = sessions.get(s.id);
            const wasWorking = statuses.get(s.id);
            if (existing.name !== s.name || existing.projectId !== s.projectId || wasWorking !== s.working) {
              sessions.set(s.id, s);
              statuses.set(s.id, s.working || false);
              changed = true;
            }
          }
        }
        
        // Check for removed sessions
        const currentIds = new Set(allSessions.map(s => s.id));
        for (const id of sessions.keys()) {
          if (!currentIds.has(id)) {
            sessions.delete(id);
            statuses.delete(id);
            changed = true;
          }
        }

        // Always update tray to ensure the Go binary doesn't miss the initial update
        if (changed) {
          api.log(`[syncSessions] Sessions changed. Count: ${sessions.size}`);
        }
        updateTray();
      } catch (e) {
        api.log(`[syncSessions] Error: ${e.message}`);
      }
    }

    // Run sync periodically to catch newly created/deleted sessions
    const syncInterval = setInterval(syncSessions, 2000);
    syncSessions();

    api.onStatusChange((sessionId, working, source) => {
      const s = api.getSession(sessionId);
      if (s) sessions.set(sessionId, s);
      
      const wasWorking = statuses.get(sessionId);
      statuses.set(sessionId, working);
      
      if (wasWorking === true && working === false) {
        const name = s ? (s.name || s.presetId) : sessionId;
        try {
          notifier.notify({
            title: 'CliDeck Agent Finished',
            message: `${name} has finished working and is now idle.`,
            icon: join(__dirname, 'icon.png'),
            sound: true,
            wait: false
          });
        } catch(e) {}
      }

      updateTray();
    });

    api.onSessionOutput((sessionId, data) => {
      if (!sessions.has(sessionId)) {
        const s = api.getSession(sessionId);
        if (s) {
          sessions.set(sessionId, s);
          updateTray();
        }
      }
    });

    api.onSettingsChange((key, value) => {
      if (key === 'enabled') {
        enabled = value;
        if (enabled) initTray();
        else killTray();
      }
    });

    api.onShutdown(() => {
      killTray();
    });
  }
};
