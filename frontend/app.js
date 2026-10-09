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
function conversionButton(path){return [...document.querySelectorAll("[data-convert]")].find(b=>b.dataset.convert===path);}
function startConversion(button){if(button.disabled)return;button.disabled=true;button.classList.add("conversion-active");button.dataset.original=button.textContent;button.innerHTML='<span class="conversion-label">0%</span><span class="conversion-track"><span class="conversion-fill"></span></span>';call("convert",[button.dataset.convert,button.dataset.kind],ok=>{if(ok===false)finishConversion(button,false,"Conversion could not be started.");});}
function finishConversion(button,success,message){if(!button)return;if(!success){button.disabled=false;button.classList.remove("conversion-active");button.textContent=button.dataset.original||"Convert";if(message)alert("Conversion failed: "+message);return}button.disabled=true;button.classList.remove("conversion-active");button.classList.add("conversion-success");button.innerHTML='<span class="success-check">✓</span> Success';const panel=$("preview-panel");if(panel)panel.innerHTML='<div class="preview-empty"><span class="preview-empty-icon">▤</span><strong>Document preview</strong><p>Conversion completed. Select the renamed file to preview it.</p></div>';setTimeout(()=>{button.classList.add("conversion-fading");setTimeout(()=>{button.classList.remove("conversion-success","conversion-fading");button.disabled=false;button.textContent=button.dataset.original||"Convert";refresh()},350)},3000);}

function modal(title,body){let m=$("modal");m.classList.remove("hidden");m.innerHTML='<div class="modal-card"><div class="modal-head"><b>'+esc(title)+'</b><button class="ui-button" id="close-modal">Close</button></div><div class="modal-body">'+body+'</div></div>';$("close-modal").onclick=()=>m.classList.add("hidden");}
function openDeleteConfirmation(path, name) {
  const overlay = $("delete-confirm-overlay");
  const nameLabel = $("delete-confirm-name");
  const yes = $("delete-confirm-yes");
  const no = $("delete-confirm-no");
  if (!overlay || !nameLabel || !yes || !no) return;
  nameLabel.textContent = name;
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
    close();
    call("deleteFile", [path], raw => {
      const ok = raw === true || raw === "true";
      if (ok) refresh();
      else window.alert("Digi could not delete this file. It may have moved, or it may be outside the Digi library.");
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
  const hide = () => { menu.hidden = true; };
  document.addEventListener('contextmenu', event => {
    event.preventDefault();
    target = event.target instanceof Element ? event.target : null;
    const editable = target && (target.closest('input, textarea, [contenteditable="true"], [contenteditable=""]'));
    const resultCard = target && target.closest('.result[data-preview]');
    const deleteButton = menu.querySelector('[data-action="delete-result"]');
    if (deleteButton) {
      deleteButton.hidden = !resultCard;
      deleteButton.dataset.path = resultCard ? resultCard.dataset.preview : '';
      deleteButton.dataset.name = resultCard ? (resultCard.dataset.name || '') : '';
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
        const isOpen = wrapper && wrapper.classList.toggle('submenu-open');
        button.setAttribute('aria-expanded', String(!!isOpen));
      }
      else if (action === 'new-docx' || action === 'new-pdf') {
        hide();
        const kind = action === 'new-docx' ? 'docx' : 'pdf';
        const label = kind === 'docx' ? 'Word document' : 'PDF document';
        modal('New ' + (kind === 'docx' ? 'DOCX' : 'PDF'),
          '<form id="new-document-form" class="new-document-form"><label for="new-document-name">File name</label><input id="new-document-name" name="name" required maxlength="180" placeholder="My document" autocomplete="off"><p>The file will be created in your configured search repository.</p><div class="new-document-actions"><button type="button" class="small-button" id="new-document-cancel">Cancel</button><button type="submit" class="small-button">Create ' + (kind === 'docx' ? 'DOCX' : 'PDF') + '</button></div></form>');
        const form = $('new-document-form');
        const input = $('new-document-name');
        if (input) input.focus();
        $('new-document-cancel').onclick = () => $('modal').classList.add('hidden');
        form.onsubmit = event => {
          event.preventDefault();
          const name = input.value.trim();
          if (!name) { input.focus(); return; }
          const submit = form.querySelector('[type="submit"]');
          submit.disabled = true;
          submit.textContent = 'Creating…';
          call('createDocument', ['', name, kind], raw => {
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
            const path = result.path;
            $('modal').classList.add('hidden');
            if (typeof refresh === 'function') refresh();
          });
        };
      }
      else if (action === 'back') history.back();
      else if (action === 'forward') history.forward();
      else if (action === 'reload') window.location.reload();
      else if (action === 'delete-result') {
        const path = button.dataset.path;
        const name = button.dataset.name || path;
        if (!path || !target || !target.closest('.result[data-preview]')) return;
        hide();
        openDeleteConfirmation(path, name);
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
    hide();
  });
})();

// Close preview from its header; refresh is placed beside the search field.
document.addEventListener('click', event => {
  if (event.target && event.target.id === 'preview-close') $('preview-panel').hidden = true;
});
