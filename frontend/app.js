let backend=null,notes={current:null,canvas:null,ctx:null,dirty:false,color:"#111111",size:3,tool:"pen"};
const $=id=>document.getElementById(id), esc=s=>String(s).replace(/[&<>"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));

function parseJson(raw,fallback,label){try{return JSON.parse(raw)}catch(error){console.error("Digi received invalid JSON from "+label,error);return fallback}}
function call(name,args,cb){if(backend)backend[name](...(args||[]),cb||function(){});}
function showStartupError(message){$("hint").textContent="Digi could not start safely.";$("results").innerHTML='<div class="empty"><strong>Digi needs assistance to start.</strong><br><br>'+esc(message||"A required application data item is missing or invalid.")+'<br><br>Digi has not automatically moved, deleted, or repaired your existing data. Do not rename or delete data folders to try to fix this. Visit the official Digi website for troubleshooting, or contact Digi support if you cannot resolve the problem.</div>';$("count").textContent="Unavailable";}
function openSelectedFile(path){call("openFile",[path],ok=>{if(ok!==true){alert("Digi could not open the selected file directly. No changes were made to the file. Check Digi Dependencies/Cache/launcher_output.txt for the requested path and the exact Word error.");}});}
function showPreview(path,name,card){
document.querySelectorAll(".result.is-selected").forEach(el=>el.classList.remove("is-selected"));
if(card)card.classList.add("is-selected");
const panel=$("preview-panel");
panel.hidden=false;
panel.innerHTML='<div class="preview-loading"><span class="preview-spinner"></span><strong>Preparing preview</strong><p>'+esc(name)+'</p></div>';
call("previewFile",[path],raw=>{
const data=parseJson(raw,null,"document preview");
if(!data){panel.innerHTML='<div class="preview-empty"><strong>Preview unavailable</strong><p>Digi could not read the preview response.</p></div>';return}
if(data.kind==="error"){panel.innerHTML='<div class="preview-empty"><strong>Preview unavailable</strong><p>'+esc(data.message||"This file cannot be previewed.")+'</p><button class="small-button" id="preview-open">Open in app</button></div>';const b=$("preview-open");if(b)b.onclick=()=>call("openFile",[path]);return}
if(data.kind==="word"){
panel.innerHTML='<div class="preview-head"><div><span class="preview-type">WORD DOCUMENT</span><strong>'+esc(data.name||name)+'</strong></div><div class="preview-head-actions"><button class="small-button" id="preview-open">Open</button><button class="small-button preview-close" id="preview-close" aria-label="Close preview" title="Close preview">×</button></div></div><div class="word-preview">'+(data.html||"")+'</div>';
const b=$("preview-open");if(b)b.onclick=()=>openSelectedFile(path);const close=$("preview-close");if(close)close.onclick=()=>{$("preview-panel").hidden=true;};return;
}
if(data.kind==="pdf"){
panel.innerHTML='<div class="preview-head"><div><span class="preview-type">PDF DOCUMENT</span><strong>'+esc(data.name||name)+'</strong><small>'+esc(String(data.total||0))+' pages</small></div><button class="small-button" id="preview-open">Open</button></div><div class="pdf-preview">'+(data.pages||[]).map(p=>'<figure class="pdf-page"><img alt="Page '+esc(p.number)+'" src="'+p.image+'"><figcaption>Page '+esc(p.number)+'</figcaption></figure>').join("")+(data.truncated?'<p class="preview-note">Showing the first 20 pages. Open the document to view the rest.</p>':"")+'</div>';
const b=$("preview-open");if(b)b.onclick=()=>openSelectedFile(path);return;
}
panel.innerHTML='<div class="preview-empty"><strong>Preview unavailable</strong><p>This document format is not supported.</p></div>';
});
}
function refresh(){let q=$("search").value.trim();if(!q){$("results").innerHTML='<div class="empty">Type a search term to show files.</div>';$("count").textContent="0 results";$("preview-panel").innerHTML='<div class="preview-empty"><span class="preview-empty-icon">▤</span><strong>Document preview</strong><p>Select a search result to view it here.</p></div>';return}
call("search",[q,$("type").value,$("status").value,$("source").value,$("method").value,$("sort").value],raw=>{let rows=parseJson(raw,null,"search results");if(!Array.isArray(rows)){$("results").innerHTML='<div class="empty">Digi could not read search results. Check the startup log.</div>';$("count").textContent="Unavailable";return}$("count").textContent=rows.length+" result(s)";$("results").innerHTML=rows.length?rows.map(r=>'<article class="result" tabindex="0" role="button" aria-label="Preview '+esc(r.name)+'" data-preview="'+esc(r.path)+'" data-name="'+esc(r.name)+'"><div class="result-name">'+esc(r.name)+'</div><div class="result-meta">'+esc(r.path)+' · '+esc(r.ext)+' · '+(r.pages||0)+' pages · '+esc(r.status)+'</div><div class="result-actions"><button class="small-button" data-open="'+esc(r.path)+'">Open</button><button class="small-button" data-folder="'+esc(r.path)+'">Folder</button><button class="small-button" data-convert="'+esc(r.path)+'" data-kind="'+(r.ext===".pdf"?"word":"pdf")+'">'+(r.ext===".pdf"?"→ Word":"→ PDF")+'</button></div></article>').join(""):'<div class="empty">No matching files.</div>';
document.querySelectorAll("[data-preview]").forEach(card=>{const select=()=>showPreview(card.dataset.preview,card.dataset.name,card);card.onclick=e=>{if(e.target.closest("button"))return;select()};card.onkeydown=e=>{if((e.key==="Enter"||e.key===" ")&&!e.target.closest("button")){e.preventDefault();select()}};});
document.querySelectorAll("[data-open]").forEach(b=>b.onclick=e=>{e.stopPropagation();openSelectedFile(b.dataset.open)});document.querySelectorAll("[data-folder]").forEach(b=>b.onclick=e=>{e.stopPropagation();call("openFolder",[b.dataset.folder])});document.querySelectorAll("[data-convert]").forEach(b=>b.onclick=e=>{e.stopPropagation();startConversion(b)});});}
function openSearchRepositoryBrowser(initialPath = "") {
  modal("Search repository", '<div class="repo-browser"><div class="repo-browser-path-wrap"><span class="repo-browser-path-prefix">Search Repository /</span><input class="repo-browser-path" id="repo-browser-path" aria-label="Repository folder path" autocomplete="off" spellcheck="false" placeholder="(root)"><span class="repo-browser-path-help">Edit path and press Enter to navigate</span></div><div class="repo-browser-list" id="repo-browser-list"><div class="empty">Loading folders…</div></div></div>');
  let current = "";
  const renderRepository = path => {
    // Never let an event object become a filesystem path.
    current = typeof path === "string" ? path : "";
    const list = $("repo-browser-list");
    const pathLabel = $("repo-browser-path");
    if (!list || !pathLabel) return;
    pathLabel.dataset.path = current;
    pathLabel.dataset.currentPath = current;
    const displayPath = current.replace(/\\/g, '/');
    // Display only the path relative to the configured repository root.
    pathLabel.value = displayPath ? displayPath.split('/').filter(Boolean).slice(-1).join('/') : '';
    pathLabel.dataset.fullPath = current;
    const contextAddFolder = document.querySelector('#digi-context-menu [data-action="add-folder"]');
    if (contextAddFolder) contextAddFolder.dataset.parent = current;
    list.innerHTML = '<div class="empty">Loading…</div>';
    call("listLibraryContents", [current], raw => {
      const data = parseJson(raw, null, "search repository browser");
      if (!list.isConnected) return;
      if (!data || !data.ok) {
        list.innerHTML = '<div class="empty">Could not load this folder.</div>';
        return;
      }
      // Canonicalize the current path from the backend and show it relative to
      // the repository root, never as a C:\\... filesystem path.
      current = data.current || current;
      pathLabel.dataset.currentPath = current;
      pathLabel.dataset.path = current;
      const rootPath = String(data.root || '').replace(/\\/g, '/').replace(/\/$/, '');
      const normalizedCurrent = String(current || '').replace(/\\/g, '/');
      const relativePath = normalizedCurrent.startsWith(rootPath) ? normalizedCurrent.slice(rootPath.length).replace(/^\/+/, '') : '';
      pathLabel.value = relativePath;
      list.innerHTML = "";
      if (data.parent) {
        const up = document.createElement("button");
        up.type = "button";
        up.className = "repo-browser-entry repo-browser-up";
        up.textContent = "←  Back";
        up.onclick = () => renderRepository(data.parent);
        list.appendChild(up);
      }
      if (!data.entries.length) {
        const empty = document.createElement("div");
        empty.className = "empty";
        empty.textContent = "This folder is empty.";
        list.appendChild(empty);
      }
      data.entries.forEach(entry => {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "repo-browser-entry";
        button.dataset.type = entry.type;
        button.dataset.path = entry.path;
        button.dataset.name = entry.name;
        const isFolder = entry.type === "folder";
        button.innerHTML = '<span class="repo-browser-entry-icon" aria-hidden="true">' + (isFolder
          ? '<svg viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 7a2 2 0 0 1 2-2h5l2 2h7a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></svg>'
          : '<svg viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3h8l4 4v14H6z"/><path d="M14 3v5h5"/></svg>') + '</span><span class="repo-browser-entry-name"></span><span class="repo-browser-entry-arrow">' + (isFolder ? "›" : "↗") + '</span>';
        button.querySelector(".repo-browser-entry-name").textContent = entry.name;
        // Do not expose the full filesystem path as a native hover tooltip.
        button.removeAttribute("title");
        button.onclick = () => {
          if (isFolder) renderRepository(entry.path);
          else call("openFile", [entry.path], ok => {
            if (ok !== true) {
              const message = $("repo-browser-path");
              if (message) message.textContent = "Could not open " + entry.name;
            }
          });
        };
        list.appendChild(button);
      });
    });
  };
  const pathInput = $("repo-browser-path");
  if (pathInput) {
    pathInput.addEventListener('keydown', event => {
      if (event.key !== 'Enter') return;
      event.preventDefault();
      const prefix = document.querySelector('.repo-browser-path-prefix');
      let typed = pathInput.value.trim().replace(/\\/g, '/').replace(/^\/+|\/+$/g, '');
      typed = typed.replace(/^search repository\s*\/?/i, '').replace(/^\/+/, '');
      if (typed.split('/').some(part => part === '..')) {
        showRepositoryDropMessage('Invalid folder path', 'Use a path inside Search Repository. Parent traversal is not allowed.');
        return;
      }
      renderRepository(typed);
    });
  }
  const browser = $("repo-browser-list");
  if (browser) {
    browser.oncontextmenu = event => {
      event.preventDefault();
      const pathLabel = $("repo-browser-path");
      const addFolder = document.querySelector('#digi-context-menu [data-action="add-folder"]');
      if (addFolder) addFolder.dataset.parent = pathLabel ? (pathLabel.dataset.path || "") : "";
    };
    let dragDepth = 0;
    const showDropState = active => {
      browser.classList.toggle('repo-browser-drop-active', active);
      let hint = browser.querySelector('.repo-browser-drop-hint');
      if (active && !hint) {
        hint = document.createElement('div');
        hint.className = 'repo-browser-drop-hint';
        hint.textContent = 'Drop folder to add it here';
        browser.appendChild(hint);
      } else if (!active && hint) hint.remove();
    };
    browser.addEventListener('dragenter', event => {
      event.preventDefault();
      dragDepth++;
      showDropState(true);
    });
    browser.addEventListener('dragover', event => {
      event.preventDefault();
      if (event.dataTransfer) event.dataTransfer.dropEffect = 'copy';
      showDropState(true);
    });
    browser.addEventListener('dragleave', event => {
      event.preventDefault();
      dragDepth = Math.max(0, dragDepth - 1);
      if (!dragDepth) showDropState(false);
    });
    browser.addEventListener('drop', event => {
      event.preventDefault();
      dragDepth = 0;
      showDropState(false);
      const transfer = event.dataTransfer;
      const uriText = transfer ? (transfer.getData('text/uri-list') || transfer.getData('text/plain')) : '';
      const uri = uriText.split(/\r?\n/).map(line => line.trim()).find(line => line && !line.startsWith('#') && /^file:/i.test(line));
      if (!uri) {
        // Native Qt drag/drop handles folders. HTML5 drops without a usable
        // folder URI are commonly individual files, which Digi does not import.
        showRepositoryDropMessage('Folder only', 'Drop a folder into the repository list. Individual files cannot be added by this action.');
        return;
      }
      let sourcePath = '';
      try {
        const parsed = new URL(uri);
        sourcePath = decodeURIComponent(parsed.pathname);
        if (/^\/[a-zA-Z]:/.test(sourcePath)) sourcePath = sourcePath.slice(1);
        sourcePath = sourcePath.replace(/\//g, '\\');
        if (parsed.hostname && parsed.hostname !== 'localhost') sourcePath = '\\\\' + parsed.hostname + sourcePath;
      } catch (_) {}
      if (!sourcePath) return;
      const pathLabel = $('repo-browser-path');
      const destination = pathLabel && typeof pathLabel.dataset.currentPath === 'string' ? pathLabel.dataset.currentPath : '';
      browser.classList.add('repo-browser-importing');
      call('importFolder', [sourcePath, destination], raw => {
        browser.classList.remove('repo-browser-importing');
        const result = parseJson(raw, null, 'folder import');
        if (!result || !result.ok) {
          modal('Could not add folder', '<p class="repo-browser-drop-message">' + esc(result && result.error ? result.error : 'Digi could not import this folder.') + '</p><div class="new-document-actions"><button type="button" class="new-document-create" id="repo-drop-close">Close</button></div>');
          $('repo-drop-close').onclick = () => {
            $('modal').classList.add('hidden');
            openSearchRepositoryBrowser(destination);
          };
          return;
        }
        openSearchRepositoryBrowser(destination);
        if (typeof refresh === 'function') refresh();
      });
    });
  }
  renderRepository(initialPath);
}
function showRepositoryDropMessage(title, message) {
  document.querySelectorAll('.repo-drop-alert').forEach(node => node.remove());
  const overlay = document.createElement('div');
  overlay.className = 'repo-drop-alert';
  overlay.innerHTML = '<div class="repo-drop-alert-card" role="alertdialog" aria-modal="true" aria-labelledby="repo-drop-alert-title"><div class="repo-drop-alert-title" id="repo-drop-alert-title"></div><p class="repo-drop-alert-message"></p><div class="repo-drop-alert-actions"><button type="button" class="repo-drop-alert-ok">Okay</button></div></div>';
  overlay.querySelector('.repo-drop-alert-title').textContent = title || 'Could not add folder';
  overlay.querySelector('.repo-drop-alert-message').textContent = message || 'Digi could not add the dropped folder.';
  const close = () => overlay.remove();
  overlay.querySelector('.repo-drop-alert-ok').addEventListener('click', close);
  overlay.addEventListener('click', event => { if (event.target === overlay) close(); });
  document.addEventListener('keydown', function onKey(event) {
    if (event.key === 'Escape' && document.body.contains(overlay)) {
      close();
      document.removeEventListener('keydown', onKey);
    }
  });
  document.body.appendChild(overlay);
  overlay.querySelector('.repo-drop-alert-ok').focus();
}
window.handleNativeFolderDrop = function (serializedPaths, dropX, dropY) {
  const dropTarget = document.elementFromPoint(Number(dropX) || 0, Number(dropY) || 0);
  if (!dropTarget || !dropTarget.closest('.repo-browser-list')) return;
  let paths = [];
  try { paths = JSON.parse(serializedPaths || '[]'); } catch (_) {}
  paths = Array.isArray(paths) ? paths.filter(path => typeof path === 'string' && path.trim()) : [];
  const browser = document.querySelector('.repo-browser');
  if (!browser || !paths.length) {
    showRepositoryDropMessage('Open Search Repository', 'Open Digi’s Search Repository explorer, then drop the folder into its folder list.');
    return;
  }
  const pathLabel = browser.querySelector('#repo-browser-path');
  const destination = pathLabel && typeof pathLabel.dataset.currentPath === 'string' ? pathLabel.dataset.currentPath : '';
  const list = browser.querySelector('#repo-browser-list');
  if (list) list.classList.add('repo-browser-importing');
  const importNext = index => {
    if (index >= paths.length) {
      if (list) list.classList.remove('repo-browser-importing');
      openSearchRepositoryBrowser(destination);
      if (typeof refresh === 'function') refresh();
      return;
    }
    call('importFolder', [paths[index], destination], raw => {
      const result = parseJson(raw, null, 'folder import');
      if (!result || !result.ok) {
        if (list) list.classList.remove('repo-browser-importing');
        showRepositoryDropMessage('Could not add folder', result && result.error ? result.error : 'Digi could not read or copy this folder.');
        return;
      }
      importNext(index + 1);
    });
  };
  importNext(0);
};
const repositoryButton = $("open-search-repository");
if (repositoryButton) repositoryButton.addEventListener("click", openSearchRepositoryBrowser);
function conversionButton(path){return [...document.querySelectorAll("[data-convert]")].find(b=>b.dataset.convert===path);}
function startConversion(button){if(button.disabled)return;button.disabled=true;button.classList.add("conversion-active");button.dataset.original=button.textContent;button.innerHTML='<span class="conversion-label">0%</span><span class="conversion-track"><span class="conversion-fill"></span></span>';call("convert",[button.dataset.convert,button.dataset.kind],ok=>{if(ok===false)finishConversion(button,false,"Conversion could not be started.");});}
function finishConversion(button,success,message){if(!button)return;if(!success){button.disabled=false;button.classList.remove("conversion-active");button.textContent=button.dataset.original||"Convert";if(message)alert("Conversion failed: "+message);return}button.disabled=true;button.classList.remove("conversion-active");button.classList.add("conversion-success");button.innerHTML='<span class="success-check">✓</span> Success';const panel=$("preview-panel");if(panel)panel.innerHTML='<div class="preview-empty"><span class="preview-empty-icon">▤</span><strong>Document preview</strong><p>Conversion completed. Select the renamed file to preview it.</p></div>';setTimeout(()=>{button.classList.add("conversion-fading");setTimeout(()=>{button.classList.remove("conversion-success","conversion-fading");button.disabled=false;button.textContent=button.dataset.original||"Convert";refresh()},350)},3000);}

function modal(title,body){let m=$("modal");m.classList.remove("hidden");m.innerHTML='<div class="modal-card"><div class="modal-head"><b>'+esc(title)+'</b><button class="ui-button" id="close-modal">Close</button></div><div class="modal-body">'+body+'</div></div>';$("close-modal").onclick=()=>m.classList.add("hidden");}
function openMoveBrowser(sourcePath, sourceName) {
  modal('Move file', '<div class="move-browser"><div class="move-source-label">Selected file: <strong>'+esc(sourceName)+'</strong></div><div class="move-browser-list" id="move-browser-list"><div class="empty">Loading contents…</div></div><div class="folder-context-menu" id="folder-context-menu" hidden><button type="button" id="folder-context-add">＋ Add folder</button><button type="button" id="folder-context-delete">Delete file</button><button type="button" id="folder-context-delete-folder" hidden>Delete folder</button></div><div class="delete-file-overlay" id="delete-file-overlay" hidden><section class="delete-file-confirm" role="dialog" aria-modal="true" aria-labelledby="delete-file-title"><h3 id="delete-file-title">Delete this file?</h3><p id="delete-file-description">This action cannot be undone.</p><div class="delete-file-actions"><button type="button" id="delete-file-no">No</button><button type="button" id="delete-file-yes">Yes</button></div></section></div><div class="new-folder-overlay" id="new-folder-overlay" hidden><section class="new-folder-popup" role="dialog" aria-modal="true" aria-labelledby="new-folder-title"><div class="new-folder-tab"><span class="rename-popup-tab-mark" aria-hidden="true"></span><span>New folder</span><button type="button" id="new-folder-close" aria-label="Close">×</button></div><form id="new-folder-form"><h3 id="new-folder-title">Create a folder</h3><label for="new-folder-name">Folder name</label><input id="new-folder-name" name="foldername" type="text" maxlength="120" required autocomplete="off"><div class="new-folder-actions"><button type="button" id="new-folder-cancel">Cancel</button><button type="submit" id="new-folder-create">Create folder</button></div></form></section></div><div class="move-browser-actions"><span id="move-browser-message" role="status"></span><button class="ui-button move-here-button" id="move-here" type="button" disabled>Move here</button></div><div class="rename-popup-overlay" id="rename-popup-overlay" hidden><section class="rename-popup" role="dialog" aria-modal="true" aria-labelledby="rename-popup-title"><div class="rename-popup-tab"><span class="rename-popup-tab-mark" aria-hidden="true"></span><span>Rename file</span><button type="button" id="rename-popup-close" aria-label="Close rename popup">×</button></div><form id="rename-popup-form" class="rename-popup-form"><h3 id="rename-popup-title">Choose a new filename</h3><p>A file with this name already exists in the destination folder.</p><label for="rename-popup-input">New filename</label><input id="rename-popup-input" name="filename" type="text" maxlength="240" required autocomplete="off"><div class="rename-popup-actions"><button type="button" class="rename-popup-cancel" id="rename-popup-cancel">Cancel</button><button type="submit" class="rename-popup-confirm" id="rename-popup-confirm">Rename and move</button></div></form></section></div></div>');
  let currentFolder = '';
  let breadcrumbFolders = [];
  let checkRequest = 0;
  let destinationConflict = false;
  let identicalConflict = false;
  const setMoveMessage = (text, isError = false) => {
    const message = $('move-browser-message');
    if (!message) return;
    message.textContent = text || '';
    message.classList.toggle('move-browser-message-error', Boolean(isError));
  };
  const render = folder => {
    currentFolder = folder || '';
    call('listLibraryContents', [currentFolder], raw => {
      const data = parseJson(raw, null, 'move browser contents');
      const list = $('move-browser-list');
      if (!list) return;
      if (!data || !data.ok) {
        list.textContent = data && data.error ? data.error : 'The repository contents could not be loaded.';
        $('move-here').disabled = true;
        setMoveMessage('Could not load this folder.', true);
        return;
      }
      list.innerHTML = '';
      const normalizePath = value => String(value || '').replace(/\\\\/g, '/').replace(/\/$/, '').toLowerCase();
      const visibleEntries = data.entries.filter(entry =>
        entry.type === 'folder' || normalizePath(entry.path) === normalizePath(sourcePath)
      );
      list.classList.toggle('is-empty', visibleEntries.length === 0);
      if (data.parent || currentFolder) {
        const nav = document.createElement('div');
        nav.className = 'move-browser-nav';
        if (data.parent) {
          const up = document.createElement('button');
          up.type = 'button';
          up.className = 'move-browser-back';
          up.title = 'Go to parent folder';
          up.setAttribute('aria-label', 'Go to parent folder');
          up.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5"/><path d="m12 19-7-7 7-7"/></svg>';
          up.onclick = () => { breadcrumbFolders.pop(); render(data.parent); };
          nav.appendChild(up);
        }
        const breadcrumb = document.createElement('div');
        breadcrumb.className = 'move-browser-breadcrumb';
        breadcrumb.setAttribute('aria-label', 'Current directory');
        const parts = breadcrumbFolders;
        parts.forEach((item, index) => {
          if (index) {
            const arrow = document.createElement('span');
            arrow.className = 'move-browser-breadcrumb-arrow';
            arrow.setAttribute('aria-hidden', 'true');
            arrow.innerHTML = '<svg viewBox="0 0 16 16" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="m6 3 5 5-5 5"/></svg>';
            breadcrumb.appendChild(arrow);
          }
          const accumulated = item.path;
          const segment = document.createElement('button');
          segment.type = 'button';
          segment.className = 'move-browser-breadcrumb-segment' + (index === parts.length - 1 ? ' is-current' : '');
          segment.textContent = item.name;
          segment.title = 'Open ' + accumulated;
          segment.disabled = index === parts.length - 1;
          segment.onclick = () => { breadcrumbFolders = breadcrumbFolders.slice(0, index + 1); render(accumulated); };
          breadcrumb.appendChild(segment);
        });
        nav.appendChild(breadcrumb);
        list.appendChild(nav);
      }
      if (!visibleEntries.length) {
        const empty = document.createElement('div'); empty.className = 'empty'; empty.textContent = 'This folder is empty.'; list.appendChild(empty);
      }
      const contextMenu = $('folder-context-menu');
      let contextTargetIsFile = false;
      let contextTargetFolderPath = '';
      list.oncontextmenu = event => {
        event.preventDefault();
        const fileRow = event.target.closest('.move-browser-current-file');
        const folderRow = event.target.closest('.move-browser-folder');
        contextTargetIsFile = Boolean(fileRow);
        contextTargetFolderPath = folderRow ? (folderRow.dataset.path || '') : '';
        $('folder-context-add').hidden = false;
        $('folder-context-delete').hidden = !contextTargetIsFile;
        $('folder-context-delete-folder').hidden = !folderRow;
        contextMenu.style.left = Math.max(8, Math.min(event.clientX, window.innerWidth - 190)) + 'px';
        contextMenu.style.top = Math.max(8, Math.min(event.clientY, window.innerHeight - 70)) + 'px';
        contextMenu.hidden = false;
      };
      const hideFolderMenu = () => { if (contextMenu) contextMenu.hidden = true; };
      document.addEventListener('pointerdown', event => {
        if (contextMenu && !contextMenu.contains(event.target)) hideFolderMenu();
      });
      const openNewFolderPopup = () => {
        hideFolderMenu();
        const overlay = $('new-folder-overlay');
        const input = $('new-folder-name');
        const form = $('new-folder-form');
        const close = () => { overlay.hidden = true; };
        input.value = '';
        overlay.hidden = false;
        $('new-folder-close').onclick = close;
        $('new-folder-cancel').onclick = close;
        input.focus();
        form.onsubmit = event => {
          event.preventDefault();
          const name = input.value.trim();
          if (!name) { input.focus(); return; }
          if (/[<>:"/\\\\|?*]/.test(name) || name === '.' || name === '..') {
            setMoveMessage('That folder name contains invalid characters.', true);
            input.focus();
            return;
          }
          const createButton = $('new-folder-create');
          createButton.disabled = true;
          setMoveMessage('Creating folder…');
          call('createFolder', [currentFolder, name], rawResult => {
            createButton.disabled = false;
            const result = parseJson(rawResult, null, 'create folder');
            if (result === true || (result && result.ok)) {
              close();
              setMoveMessage('Folder created.');
              render(currentFolder);
            } else {
              setMoveMessage(result && result.error ? result.error : 'Could not create folder.', true);
            }
          });
        };
      };
      $('folder-context-add').onclick = openNewFolderPopup;
      $('folder-context-delete').onclick = () => {
        hideFolderMenu();
        const overlay = $('delete-file-overlay');
        $('delete-file-description').textContent = 'Delete “' + sourceName + '”? This cannot be undone.';
        overlay.hidden = false;
        $('delete-file-no').onclick = () => { overlay.hidden = true; };
        $('delete-file-yes').onclick = () => {
          const yes = $('delete-file-yes');
          yes.disabled = true;
          call('deleteFile', [sourcePath], raw => {
            yes.disabled = false;
            const deleted = raw === true || raw === 'true';
            if (deleted) {
              overlay.hidden = true;
              $('modal').classList.add('hidden');
              refresh();
            } else {
              $('delete-file-description').textContent = 'Digi could not delete this file. It may no longer exist or may be outside the repository.';
            }
          });
        };
      };
      $('folder-context-delete-folder').onclick = () => {
        hideFolderMenu();
        const folderPath = contextTargetFolderPath;
        const folderName = folderPath.split(/[\\\\/]/).filter(Boolean).pop() || 'this folder';
        const overlay = $('delete-file-overlay');
        $('delete-file-title').textContent = 'Delete this folder?';
        $('delete-file-description').textContent = 'Delete “' + folderName + '” and everything inside it? This cannot be undone.';
        overlay.hidden = false;
        $('delete-file-no').onclick = () => { overlay.hidden = true; };
        $('delete-file-yes').onclick = () => {
          const yes = $('delete-file-yes');
          yes.disabled = true;
          call('deleteFolder', [folderPath], raw => {
            yes.disabled = false;
            const deleted = raw === true || raw === 'true';
            if (deleted) {
              overlay.hidden = true;
              $('delete-file-title').textContent = 'Delete this file?';
              render(currentFolder);
            } else {
              $('delete-file-description').textContent = 'Digi could not delete this folder.';
            }
          });
        };
      };
      visibleEntries.forEach(entry => {
        const row = document.createElement('button');
        row.type = 'button'; row.className = 'move-browser-entry';
        const isSourceFile = entry.type === 'file' && normalizePath(entry.path) === normalizePath(sourcePath);
        if (isSourceFile) {
          row.classList.add('move-browser-current-file');
          const arrow = document.createElement('span');
          arrow.className = 'move-browser-current-arrow';
          arrow.setAttribute('aria-hidden', 'true');
          arrow.textContent = '➜';
          const name = document.createElement('span');
          name.className = 'move-browser-current-name';
          name.textContent = entry.name;
          const badge = document.createElement('span');
          badge.className = 'move-browser-current-badge';
          badge.textContent = 'YOUR FILE!';
          row.append(arrow, name, badge);
          row.disabled = true;
          row.setAttribute('aria-disabled', 'true');
          row.tabIndex = -1;
        } else {
          row.textContent = (entry.type === 'folder' ? '▣  ' : '▤  ') + entry.name;
          if (entry.type === 'folder') {
            row.classList.add('move-browser-folder');
            row.dataset.path = entry.path;
            row.onclick = () => { if (!breadcrumbFolders.length || breadcrumbFolders[breadcrumbFolders.length - 1].path !== entry.path) breadcrumbFolders.push({ path: entry.path, name: entry.name }); render(entry.path); };
          } else {
            row.classList.add('move-browser-file');
            row.disabled = true;
            row.setAttribute('aria-disabled', 'true');
            row.tabIndex = -1;
          }
        }
        list.appendChild(row);
      });
      const requestId = ++checkRequest;
      const moveButton = $('move-here');
      const message = $('move-browser-message');
      moveButton.disabled = true;
      moveButton.textContent = 'Move here';
      setMoveMessage('Checking destination…');
      call('checkMoveDestination', [sourcePath, currentFolder], rawCheck => {
        if (requestId !== checkRequest || !$('move-here')) return;
        const check = parseJson(rawCheck, null, 'move destination check');
        if (!check || !check.ok) {
          moveButton.disabled = true;
          setMoveMessage(check && check.error ? check.error : 'Could not check destination.', true);
          return;
        }
        destinationConflict = Boolean(check.conflict);
        identicalConflict = Boolean(check.identical);
        moveButton.disabled = !check.can_move && (!destinationConflict || identicalConflict);
        setMoveMessage(check.reason || '', Boolean(check.conflict || !check.can_move));
      });
    });
  };
  $('move-here').onclick = () => {
    const button = $('move-here');
    if (button.disabled) return;
    if (destinationConflict) {
      const dot = sourceName.lastIndexOf('.');
      const suggestedName = dot > 0
        ? sourceName.slice(0, dot) + ' (1)' + sourceName.slice(dot)
        : sourceName + ' (1)';
      const overlay = $('rename-popup-overlay');
      const input = $('rename-popup-input');
      const form = $('rename-popup-form');
      const close = () => { overlay.hidden = true; };
      input.value = suggestedName;
      overlay.hidden = false;
      $('rename-popup-close').onclick = close;
      $('rename-popup-cancel').onclick = close;
      input.focus();
      input.select();
      form.onsubmit = event => {
        event.preventDefault();
        const newName = input.value.trim();
        if (!newName) { input.focus(); return; }
        overlay.hidden = true;
        button.disabled = true;
        setMoveMessage('Moving file…');
        call('moveFile', [sourcePath, currentFolder, newName], raw => {
          const result = parseJson(raw, null, 'move file');
          if (result && result.ok) {
            $('modal').classList.add('hidden');
            refresh();
          } else {
            setMoveMessage(result && result.error
              ? result.error
              : 'Move failed — two files of the same name cannot be in one folder.', true);
            render(currentFolder);
          }
        });
      };
      return;
    }
    button.disabled = true;
    setMoveMessage('Moving file…');
    call('moveFile', [sourcePath, currentFolder, ''], raw => {
      const result = parseJson(raw, null, 'move file');
      if (result && result.ok) {
        $('modal').classList.add('hidden');
        refresh();
      } else {
        setMoveMessage(result && result.error
          ? result.error
          : 'Move failed — two files of the same name cannot be in one folder.', true);
        render(currentFolder);
      }
    });
  };
  render('');
}
function openDeleteConfirmation(path, name, kind = "file", onDeleted = null) {
  const overlay = $("delete-confirm-overlay");
  const title = $("delete-confirm-title");
  const nameLabel = $("delete-confirm-name");
  const yes = $("delete-confirm-yes");
  const no = $("delete-confirm-no");
  const message = overlay && overlay.querySelector(".delete-confirm-message");
  const warning = overlay && overlay.querySelector(".delete-confirm-warning");
  if (!overlay || !nameLabel || !yes || !no) return;
  if (title) title.textContent = kind === "folder" ? "DELETE FOLDER" : "DELETE FILE";
  if (message) message.firstChild.textContent = kind === "folder"
    ? "Are you sure you want to delete the folder "
    : "Are you sure you want to delete ";
  nameLabel.textContent = name;
  if (message && message.lastChild) message.lastChild.textContent = kind === "folder" ? " and all its contents?" : "?";
  if (warning) warning.textContent = "This action cannot be undone.";
  yes.textContent = kind === "folder" ? "Yes, delete folder" : "Yes, delete";
  no.textContent = kind === "folder" ? "No, keep folder" : "No, keep it";
  overlay.hidden = false;
  document.body.classList.add("delete-confirm-open");
  const close = () => {
    overlay.hidden = true;
    document.body.classList.remove("delete-confirm-open");
    yes.onclick = null;
    no.onclick = null;
  };
  no.onclick = close;
  yes.onclick = () => {
    yes.disabled = true;
    const originalLabel = yes.textContent;
    yes.textContent = "Deleting…";
    call(kind === "folder" ? "deleteFolder" : "deleteFile", [path], raw => {
      const ok = raw === true || raw === "true";
      if (ok) {
        close();
        yes.disabled = false;
        if (typeof onDeleted === "function") onDeleted();
        else refresh();
      } else {
        yes.disabled = false;
        yes.textContent = originalLabel;
        let error = overlay.querySelector(".delete-confirm-error");
        if (!error) {
          error = document.createElement("p");
          error.className = "delete-confirm-error";
          warning.insertAdjacentElement("afterend", error);
        }
        error.textContent = kind === "folder"
          ? "Digi could not delete this folder. It may have moved or be in use."
          : "Digi could not delete this file. It may have moved or be outside the Digi library.";
      }
    });
  };
  overlay.onclick = event => { if (event.target === overlay) close(); };
  const onKey = event => {
    if (event.key === "Escape" && !overlay.hidden) close();
  };
  document.addEventListener("keydown", onKey, { once: true });
}

function openNotes(){modal("Digi Notes",'<div class="note-layout"><div class="note-tree" id="note-tree"></div><div class="note-canvas-wrap"><div class="note-toolbar"><button class="small-button" id="pen">Pen</button><button class="small-button" id="eraser">Eraser</button><input id="note-color" type="color" value="#111111"><input id="note-size" type="range" min="1" max="30" value="3"><button class="small-button" id="new-book">Notebook</button><button class="small-button" id="new-page">Page</button><button class="small-button" id="save-note">Save</button></div><canvas id="note-canvas" class="note-canvas" width="1100" height="650"></canvas></div></div>');
$("pen").onclick=()=>notes.tool="pen";$("eraser").onclick=()=>notes.tool="eraser";$("note-color").oninput=e=>notes.color=e.target.value;$("note-size").oninput=e=>notes.size=+e.target.value;$("new-book").onclick=()=>{let n=prompt("Notebook name");if(n)call("createNotebook",["",n],loadNotes)};$("new-page").onclick=()=>{if(!notes.current)return alert("Select a notebook first.");let n=prompt("Page name");if(n)call("createNotePage",[notes.current,n],p=>{notes.current=p;setupCanvas();loadNotes()})};$("save-note").onclick=saveNote;setupCanvas();loadNotes();}
function setupCanvas(){let c=$("note-canvas");if(!c)return;notes.canvas=c;notes.ctx=c.getContext("2d");notes.ctx.fillStyle="#fff";notes.ctx.fillRect(0,0,c.width,c.height);let down=false,last=null,pos=e=>{let r=c.getBoundingClientRect();return{x:(e.clientX-r.left)*c.width/r.width,y:(e.clientY-r.top)*c.height/r.height}};c.onpointerdown=e=>{if(e.pointerType==="touch")return;down=true;last=pos(e);c.setPointerCapture(e.pointerId)};c.onpointermove=e=>{if(!down)return;let p=pos(e),x=notes.ctx; x.beginPath();x.moveTo(last.x,last.y);x.lineTo(p.x,p.y);x.strokeStyle=notes.tool==="eraser"?"#fff":notes.color;x.lineWidth=notes.tool==="eraser"?notes.size*4:notes.size;x.lineCap="round";x.stroke();last=p;notes.dirty=true};c.onpointerup=()=>{down=false;last=null};c.onpointercancel=()=>{down=false};}
function loadNotes(){call("notesTree",[],raw=>{let tree=parseJson(raw,null,"notes tree"),el=$("note-tree");if(!el)return;if(!Array.isArray(tree)){el.textContent="Notes could not be loaded.";return}el.innerHTML="";let walk=(items,d)=>items.forEach(x=>{let b=document.createElement("button");b.className="small-button";b.style.display="block";b.style.margin="0 0 5px "+(d*10)+"px";b.textContent=(x.type==="folder"?"▣ ":"▤ ")+x.name;b.onclick=()=>{notes.current=x.path;if(x.type==="page")call("loadNote",[x.path],loadData)};el.appendChild(b);if(x.children)walk(x.children,d+1)});walk(tree,0)});}
function loadData(data){let img=new Image();img.onload=()=>{let c=notes.canvas;c.width=Math.max(1100,img.width);c.height=Math.max(650,img.height);notes.ctx.drawImage(img,0,0);notes.dirty=false};img.src=data;}
function saveNote(){if(notes.current&&notes.canvas)call("saveNote",[notes.current,notes.canvas.toDataURL("image/png")],()=>notes.dirty=false);}
$("window-minimize").onclick=()=>call("minimizeWindow");$("window-maximize").onclick=()=>{document.documentElement.classList.toggle("window-maximized");call("toggleMaximizeWindow");};$("window-close").onclick=()=>call("closeWindow");
const filtersToggle=$("filters-toggle"), filtersOverlay=$("filters-overlay"), filtersClose=$("filters-close");
const setFiltersOpen=open=>{
  if(!filtersOverlay||!filtersToggle)return;
  filtersOverlay.hidden=!open;
  document.body.classList.toggle("filters-dialog-open",open);
  filtersToggle.setAttribute("aria-expanded",String(open));
  if(open&&filtersClose)filtersClose.focus();
};
if(filtersToggle)filtersToggle.onclick=()=>setFiltersOpen(filtersOverlay ? filtersOverlay.hidden : false);
if(filtersClose)filtersClose.onclick=()=>setFiltersOpen(false);
if(filtersOverlay)filtersOverlay.addEventListener("click",event=>{if(event.target===filtersOverlay)setFiltersOpen(false);});
document.addEventListener("keydown",event=>{if(event.key==="Escape"&&filtersOverlay&&!filtersOverlay.hidden)setFiltersOpen(false);});
let refreshButtonTimer=null;
const scheduleRefreshButton=()=>{
  const button=$("scan");
  if(!button)return;
  clearTimeout(refreshButtonTimer);
  button.hidden=true;
  if($("search").value.trim())refreshButtonTimer=setTimeout(()=>{if($("search").value.trim())button.hidden=false;},2000);
};
$("search").oninput=()=>{if(!$("search").value.trim())document.body.classList.remove("filters-open");scheduleRefreshButton();refresh();};
$("clear").onclick=()=>{$("search").value="";scheduleRefreshButton();refresh()};["type","status","source","method","sort"].forEach(id=>$(id).onchange=refresh);$("scan").onclick=()=>call("scan");$("home-notes").onclick=openNotes;$("home-wiki").onclick=()=>modal("Digi Wiki",'<div class="feature-coming"><span class="feature-coming-icon">▤</span><h2>Wiki is coming soon</h2><p>Your knowledge workspace is planned for a future Digi update.</p></div>');
new QWebChannel(qt.webChannelTransport,ch=>{backend=ch.objects.backend;window.digiBackend=backend;backend.releaseManifestResult.connect(raw=>window.dispatchEvent(new CustomEvent("digi-release-manifest",{detail:raw})));backend.indexUpdated.connect(refresh);backend.conversionProgress.connect((path,value)=>{let b=conversionButton(path);if(!b)return;let label=b.querySelector(".conversion-label"),fill=b.querySelector(".conversion-fill");if(label)label.textContent=value+"%";if(fill)fill.style.width=value+"%";});backend.conversionFinished.connect((ok,msg,path)=>{finishConversion(conversionButton(path),ok,msg);});backend.error.connect(console.error);backend.state(raw=>{
let state=parseJson(raw,null,"startup state");if(!state){showStartupError("Digi could not read its startup state.");return}
if(state.ready){refresh();return}
backend.recalibrateVersion(ok=>{
if(ok){backend.state(updated=>{let next=parseJson(updated,null,"updated startup state");if(!next){showStartupError("Digi could not read its startup state.");return}if(next.ready){$("hint").textContent="Type a search term to show files.";refresh()}else showStartupError(next.version_problem||"Backend services could not be initialised.")})}
else showStartupError(state.version_problem||"Digi could not initialise its backend.")
});
});});


// The visible gold dot can be dragged temporarily and snaps back on release.
(() => {
  const dot = document.querySelector('.digi-home-logo-dot');
  if (!dot) return;
  dot.style.cursor = 'grab';
  dot.style.touchAction = 'none';
  let drag = null;

  document.addEventListener('pointerdown', event => {
    if (event.button !== 0) return;
    const rect = dot.getBoundingClientRect();
    const padding = 24;
    const hit = event.target === dot ||
      (event.clientX >= rect.left - padding && event.clientX <= rect.right + padding &&
       event.clientY >= rect.top - padding && event.clientY <= rect.bottom + padding);
    if (!hit) return;
    event.preventDefault();
    event.stopPropagation();
    drag = { id: event.pointerId, x: event.clientX, y: event.clientY };
    dot.style.cursor = 'grabbing';
  }, true);

  document.addEventListener('pointermove', event => {
    if (!drag || event.pointerId !== drag.id) return;
    dot.style.translate = (event.clientX - drag.x) + 'px ' + (event.clientY - drag.y) + 'px';
  }, true);

  const finish = event => {
    if (!drag || (event.pointerId !== undefined && event.pointerId !== drag.id)) return;
    drag = null;
    dot.style.translate = '';
    dot.style.cursor = 'grab';
  };
  document.addEventListener('pointerup', finish, true);
  document.addEventListener('pointercancel', finish, true);
})();


// Replace the browser's right-click menu with Digi's own interface-wide menu.
(() => {
  const menu = document.getElementById('digi-context-menu');
  if (!menu) return;
  let target = null;
  let newPinnedOpen = false;
  const newWrapper = () => menu.querySelector('.digi-context-submenu');
  const closeNewSubmenu = () => {
    const wrapper = newWrapper();
    if (wrapper) {
      wrapper.classList.remove('submenu-open', 'submenu-opens-left', 'submenu-hover-open');
      const button = wrapper.querySelector('[data-action="new-menu"]');
      if (button) button.setAttribute('aria-expanded', 'false');
    }
    newPinnedOpen = false;
  };
  const hide = () => { menu.hidden = true; closeNewSubmenu(); };
  const positionNewSubmenu = wrapper => {
    if (!wrapper) return;
    wrapper.classList.remove('submenu-opens-left');
    const items = wrapper.querySelector('.digi-context-submenu-items');
    if (!items) return;
    wrapper.classList.add('submenu-open');
    const rect = wrapper.getBoundingClientRect();
    const submenuWidth = items.offsetWidth || 160;
    const roomRight = window.innerWidth - rect.right;
    const roomLeft = rect.left;
    if (roomRight < submenuWidth + 12 && roomLeft >= submenuWidth + 12) {
      wrapper.classList.add('submenu-opens-left');
    }
  };
  menu.addEventListener('pointerover', event => {
    const wrapper = event.target.closest('.digi-context-submenu');
    if (wrapper && !wrapper.contains(event.relatedTarget)) {
      wrapper.classList.add('submenu-hover-open');
      positionNewSubmenu(wrapper);
    }
  });
  menu.addEventListener('pointerout', event => {
    const wrapper = event.target.closest('.digi-context-submenu');
    if (wrapper && !wrapper.contains(event.relatedTarget) && !newPinnedOpen) {
      wrapper.classList.remove('submenu-open', 'submenu-opens-left', 'submenu-hover-open');
      const button = wrapper.querySelector('[data-action="new-menu"]');
      if (button) button.setAttribute('aria-expanded', 'false');
    }
  });
  document.addEventListener('contextmenu', event => {
    if (event.target instanceof Element && event.target.closest('.move-browser')) return;
    event.preventDefault();
    target = event.target instanceof Element ? event.target : null;
    const editable = target && (target.closest('input, textarea, [contenteditable="true"], [contenteditable=""]'));
    const resultsArea = target ? target.closest('#results') : null;
    const repositoryBrowser = target ? target.closest('.repo-browser') : null;
    const addFolderButton = menu.querySelector('[data-action="add-folder"]');
    if (addFolderButton) {
      addFolderButton.hidden = !resultsArea && !repositoryBrowser;
      if (repositoryBrowser) {
        const pathLabel = repositoryBrowser.querySelector('#repo-browser-path');
        const candidatePath = pathLabel ? pathLabel.dataset.currentPath : '';
        const parentPath = typeof candidatePath === 'string' ? candidatePath : '';
        addFolderButton.dataset.parent = parentPath;
        for (const action of ['new-docx', 'new-pdf']) {
          const createButton = menu.querySelector('[data-action="' + action + '"]');
          if (createButton) createButton.dataset.parent = parentPath;
        }
      } else if (resultsArea) {
        addFolderButton.dataset.parent = '';
        for (const action of ['new-docx', 'new-pdf']) {
          const createButton = menu.querySelector('[data-action="' + action + '"]');
          if (createButton) createButton.dataset.parent = '';
        }
      }
    }
    // Delete is available only when right-clicking the individual file card,
    // not the surrounding results container or preview panel.
    const resultCard = target ? target.closest('#results .result[data-preview]') : null;
    const repositoryEntry = target ? target.closest('.repo-browser-entry') : null;
    const repositoryFile = repositoryEntry && repositoryEntry.dataset.type === 'file' ? repositoryEntry : null;
    const repositoryFolder = repositoryEntry && repositoryEntry.dataset.type === 'folder' ? repositoryEntry : null;
    const newWrapper = menu.querySelector('.digi-context-submenu');
    const newSeparator = newWrapper && newWrapper.previousElementSibling;
    // Keep New available anywhere in the results area, including over a result card.
    if (newWrapper) {
      newWrapper.hidden = !resultsArea && !repositoryBrowser;
      if (newSeparator && newSeparator.classList.contains('digi-context-separator')) {
        newSeparator.hidden = newWrapper.hidden;
      }
      if (newWrapper.hidden) closeNewSubmenu();
    }
    const moveButton = menu.querySelector('[data-action="move-result"]');
    if (moveButton) {
      moveButton.hidden = !resultCard;
      moveButton.dataset.path = resultCard ? resultCard.dataset.preview : '';
      moveButton.dataset.name = resultCard ? (resultCard.dataset.name || '') : '';
    }
    const deleteButton = menu.querySelector('[data-action="delete-result"]');
    const deleteFolderButton = menu.querySelector('[data-action="delete-folder-result"]');
    if (deleteButton) {
      // Delete file is available for result cards and repository files only.
      deleteButton.hidden = !resultsArea && !repositoryBrowser;
      deleteButton.disabled = !resultCard && !repositoryFile;
      deleteButton.dataset.path = resultCard ? resultCard.dataset.preview : (repositoryFile ? repositoryFile.dataset.path : '');
      deleteButton.dataset.name = resultCard ? (resultCard.dataset.name || '') : (repositoryFile ? (repositoryFile.dataset.name || '') : '');
    }
    if (deleteFolderButton) {
      deleteFolderButton.hidden = !repositoryBrowser;
      deleteFolderButton.disabled = !repositoryFolder;
      deleteFolderButton.dataset.path = repositoryFolder ? repositoryFolder.dataset.path : '';
      deleteFolderButton.dataset.name = repositoryFolder ? (repositoryFolder.dataset.name || '') : '';
    }
    const selection = window.getSelection();
    const hasSelection = !!(selection && String(selection).length);
    for (const action of ['cut','copy','paste','select-all']) {
      const button = menu.querySelector('[data-action="' + action + '"]');
      if (button) button.hidden = action === 'paste' ? !(editable && !editable.readOnly && !editable.disabled) : action === 'select-all' ? !editable : !hasSelection && !editable;
    }
    const back = menu.querySelector('[data-action="back"]');
    const forward = menu.querySelector('[data-action="forward"]');
    if (back) back.disabled = history.length <= 1;
    if (forward) forward.disabled = true;
    menu.hidden = false;
    const width = menu.offsetWidth;
    const height = menu.offsetHeight;
    menu.style.left = Math.max(8, Math.min(event.clientX, window.innerWidth - width - 8)) + 'px';
    menu.style.top = Math.max(8, Math.min(event.clientY, window.innerHeight - height - 8)) + 'px';
  });
  document.addEventListener('pointerdown', event => {
    if (!menu.contains(event.target)) hide();
  }, true);
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape') hide();
  });
  menu.addEventListener('click', async event => {
    const button = event.target.closest('button[data-action]');
    if (!button || button.disabled) return;
    const action = button.dataset.action;
    const el = target && target.closest('input, textarea, [contenteditable="true"], [contenteditable=""]');
    try {
      if (action === 'new-menu') {
        const wrapper = button.closest('.digi-context-submenu');
        newPinnedOpen = !!wrapper && !newPinnedOpen;
        if (wrapper) {
          if (newPinnedOpen) {
            wrapper.classList.add('submenu-open');
            positionNewSubmenu(wrapper);
          } else {
            wrapper.classList.remove('submenu-open', 'submenu-opens-left', 'submenu-hover-open');
          }
        }
        button.setAttribute('aria-expanded', String(newPinnedOpen));
      }
      else if (action === 'add-folder') {
        // Capture the destination before modal() replaces the current browser DOM.
        const requestedParent = button.dataset.parent;
        const folderParent = typeof requestedParent === 'string' && requestedParent !== '[object PointerEvent]' ? requestedParent : '';
        hide();
        modal('Add folder', '<form id="context-new-folder-form" class="new-document-form"><label for="context-new-folder-name">Folder name</label><input id="context-new-folder-name" name="name" required maxlength="120" placeholder="New folder" autocomplete="off"><p>The folder will be created in your configured search repository.</p><div class="new-document-actions"><button type="button" class="small-button" id="context-new-folder-cancel">Cancel</button><button type="submit" class="small-button">Create folder</button></div></form>');
        const form = $('context-new-folder-form');
        const input = $('context-new-folder-name');
        if (input) input.focus();
        $('context-new-folder-cancel').onclick = () => $('modal').classList.add('hidden');
        form.onsubmit = event => {
          event.preventDefault();
          const name = input.value.trim();
          if (!name) { input.focus(); return; }
          if (/[<>:"/\\|?*]/.test(name) || name === '.' || name === '..') {
            let error = form.querySelector('.new-document-error');
            if (!error) {
              error = document.createElement('p');
              error.className = 'new-document-error';
              form.insertBefore(error, form.querySelector('.new-document-actions'));
            }
            error.textContent = 'Enter a valid folder name.';
            input.focus();
            return;
          }
          const submit = form.querySelector('[type="submit"]');
          submit.disabled = true;
          submit.textContent = 'Creating…';
          call('createFolder', [folderParent, name], raw => {
            const result = parseJson(raw, null, 'create folder');
            if (!result || !result.ok) {
              submit.disabled = false;
              submit.textContent = 'Create folder';
              let error = form.querySelector('.new-document-error');
              if (!error) {
                error = document.createElement('p');
                error.className = 'new-document-error';
                form.insertBefore(error, form.querySelector('.new-document-actions'));
              }
              error.textContent = result && result.error ? result.error : 'Digi could not create the folder.';
              return;
            }
            // The Add folder form uses Digi's shared modal. Reopen the in-app
            // repository browser after creation instead of leaving it closed.
            openSearchRepositoryBrowser(folderParent);
            if (typeof refresh === 'function') refresh();
          });
        };
      }
      else if (action === 'new-docx' || action === 'new-pdf') {
        const requestedParent = button.dataset.parent;
        const documentParent = typeof requestedParent === 'string' && requestedParent !== '[object PointerEvent]' ? requestedParent : '';
        // Capture the explorer state before modal() replaces its DOM.
        const repositoryBrowser = !!document.querySelector('.repo-browser');
        const repositoryPathLabel = document.querySelector('.repo-browser-path');
        const repositoryPath = repositoryPathLabel && typeof repositoryPathLabel.dataset.currentPath === 'string'
          ? repositoryPathLabel.dataset.currentPath
          : documentParent;
        hide();
        const kind = action === 'new-docx' ? 'docx' : 'pdf';
        const label = kind === 'docx' ? 'Word document' : 'PDF document';
        modal('New ' + (kind === 'docx' ? 'DOCX' : 'PDF'),
          '<form id="new-document-form" class="new-document-form"><label for="new-document-name">File name</label><input id="new-document-name" name="name" required maxlength="180" placeholder="My document" autocomplete="off"><p>The file will be created in your configured search repository.</p><div class="new-document-actions"><button type="button" class="new-document-cancel" id="new-document-cancel">Cancel</button><button type="submit" class="new-document-create">Create ' + (kind === 'docx' ? 'DOCX' : 'PDF') + '</button></div></form>');
        $('modal').classList.add('new-document-modal');
        const form = $('new-document-form');
        const input = $('new-document-name');
        if (input) input.focus();
        $('new-document-cancel').onclick = () => {
          $('modal').classList.add('hidden');
          $('modal').classList.remove('new-document-modal');
        };
        form.onsubmit = event => {
          event.preventDefault();
          const name = input.value.trim();
          if (!name) { input.focus(); return; }
          const submit = form.querySelector('[type="submit"]');
          submit.disabled = true;
          submit.textContent = 'Creating…';
          call('createDocument', [documentParent, name, kind], raw => {
            let result = null;
            try { result = JSON.parse(raw); } catch (_) {}
            if (!result || !result.ok || !result.path) {
              submit.disabled = false;
              submit.textContent = 'Create ' + (kind === 'docx' ? 'DOCX' : 'PDF');
              let error = form.querySelector('.new-document-error');
              if (!error) {
                error = document.createElement('p');
                error.className = 'new-document-error';
                form.insertBefore(error, form.querySelector('.new-document-actions'));
              }
              error.textContent = result && result.error ? result.error : 'Digi did not return a creation result. Check that the backend is ready.';
              return;
            }
            // Keep the user in the place where they initiated New.
            $('modal').classList.add('hidden');
            $('modal').classList.remove('new-document-modal');
            // Reopen the explorer only when creation started there; Results-box
            // creation must not unexpectedly open or switch to another view.
            if (repositoryBrowser) openSearchRepositoryBrowser(repositoryPath);
            // Refresh the index without changing the current view.
            if (typeof refresh === 'function') refresh();
          });
        };
      }
      else if (action === 'move-result') {
        const path = button.dataset.path;
        const name = button.dataset.name || path;
        hide();
        if (path) openMoveBrowser(path, name);
      }
      else if (action === 'back') history.back();
      else if (action === 'forward') history.forward();
      else if (action === 'reload') window.location.reload();
      else if (action === 'delete-result') {
        const path = button.dataset.path;
        const name = button.dataset.name || path;
        const resultTarget = target && target.closest('#results .result[data-preview]');
        const repositoryTarget = target && target.closest('.repo-browser-entry[data-type="file"]');
        if (!path || (!resultTarget && !repositoryTarget)) return;
        hide();
        if (repositoryTarget) {
          if (!window.confirm('Delete "' + name + '"? This cannot be undone.')) return;
          call('deleteFile', [path], ok => {
            if (ok === true) {
              const pathLabel = $('repo-browser-path');
              const currentPath = pathLabel && typeof pathLabel.dataset.currentPath === 'string' ? pathLabel.dataset.currentPath : '';
              openSearchRepositoryBrowser(currentPath);
              if (typeof refresh === 'function') refresh();
            } else {
              alert('Digi could not delete this file.');
            }
          });
        } else {
          openDeleteConfirmation(path, name);
        }
      }
      else if (action === 'delete-folder-result') {
        const path = button.dataset.path;
        const name = button.dataset.name || path;
        const folderTarget = target && target.closest('.repo-browser-entry[data-type="folder"]');
        if (!path || !folderTarget) return;
        hide();
        openDeleteConfirmation(path, name, "folder", () => {
          const pathLabel = $('repo-browser-path');
          const currentPath = pathLabel && typeof pathLabel.dataset.currentPath === 'string' ? pathLabel.dataset.currentPath : '';
          openSearchRepositoryBrowser(currentPath);
          if (typeof refresh === 'function') refresh();
        });
      }
      else if (action === 'select-all' && el) {
        el.focus();
        if (typeof el.select === 'function') el.select();
        else document.execCommand('selectAll');
      } else if ((action === 'cut' || action === 'copy') && window.getSelection()?.toString()) {
        document.execCommand(action);
      } else if (action === 'cut' && el && typeof el.setRangeText === 'function') {
        const start = el.selectionStart, end = el.selectionEnd;
        if (start !== end) { await navigator.clipboard.writeText(el.value.slice(start, end)); el.setRangeText('', start, end, 'start'); }
      } else if (action === 'copy' && el && typeof el.setRangeText === 'function') {
        const start = el.selectionStart, end = el.selectionEnd;
        if (start !== end) await navigator.clipboard.writeText(el.value.slice(start, end));
      } else if (action === 'paste' && el && !el.readOnly && !el.disabled && navigator.clipboard?.readText) {
        const text = await navigator.clipboard.readText();
        if (typeof el.setRangeText === 'function') {
          const start = el.selectionStart ?? el.value.length;
          const end = el.selectionEnd ?? start;
          el.setRangeText(text, start, end, 'end');
          el.dispatchEvent(new Event('input', {bubbles:true}));
        } else { el.focus(); document.execCommand('insertText', false, text); }
      }
    } catch (error) {
      console.warn('Digi context menu action could not be completed:', error);
    }
    // Keep the parent context menu open while the New submenu is toggled.
    // All other actions retain their normal close behavior.
    if (action !== 'new-menu') hide();
  });
})();

// Close preview from its header; refresh is placed beside the search field.
document.addEventListener('click', event => {
  if (event.target && event.target.id === 'preview-close') $('preview-panel').hidden = true;
});
