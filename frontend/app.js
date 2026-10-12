let backend=null,sharedStrokeClipboard=[],notes={current:null,canvas:null,ctx:null,dirty:false,color:"#111111",size:3,tool:"pen"};
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
 const renderPages=(pages,clean=false)=>(pages||[]).map(p=>'<figure class="pdf-page"><img loading="lazy" decoding="async" alt="Page '+esc(p.number)+'" data-annotations="'+esc(JSON.stringify(p.annotations||[]))+'" src="'+(clean?(p.cleanImage||p.image):p.image)+'"><figcaption>Page '+esc(p.number)+'</figcaption></figure>').join("");
 panel.innerHTML='<div class="preview-head"><div><span class="preview-type">PDF DOCUMENT</span><strong>'+esc(data.name||name)+'</strong><small>'+esc(String(data.total||0))+' pages</small></div><div class="preview-head-actions"><button type="button" class="small-button preview-deselect" id="preview-deselect" aria-label="Deselect PDF" title="Deselect PDF">×</button><button type="button" class="small-button preview-fullscreen" id="preview-fullscreen" aria-label="Open fullscreen PDF viewer" title="Open fullscreen PDF viewer"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M8 3H3v5M3 3l7 7M16 3h5v5M21 3l-7 7M3 16v5h5M3 21l7-7M21 16v5h-5M21 21l-7-7"/></svg></button></div></div><div class="pdf-preview pdf-preview-limited">'+renderPages((data.pages||[]).slice(0,5))+'</div>';
 const deselect=$("preview-deselect");if(deselect)deselect.onclick=e=>{e.stopPropagation();panel.hidden=true;document.querySelectorAll(".result.is-selected").forEach(el=>el.classList.remove("is-selected"));};
 const full=$("preview-fullscreen");
 if(full)full.onclick=()=>{document.getElementById("pdf-fullscreen-shell")?.remove();const shell=document.createElement("div");shell.id="pdf-fullscreen-shell";shell.className="pdf-fullscreen-shell";shell.innerHTML='<div class="pdf-fullscreen-viewer"><div class="pdf-viewer-toolbar" id="pdf-viewer-toolbar"><div class="pdf-viewer-toolbar-main" id="pdf-viewer-toolbar-main"><div class="pdf-viewer-toolbar-details" id="pdf-viewer-toolbar-details"><strong>'+esc(data.name||name)+'</strong><span>'+esc(String(data.total||0))+' pages</span><div class="pdf-annotation-tools" role="toolbar" aria-label="PDF annotation tools"><button type="button" class="small-button" id="pdf-select-tool" aria-pressed="false" title="Select strokes" aria-label="Select strokes"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 3v14l4-4 3 6 2-1-3-6h6L5 3Z"/><path d="M15 4h5v5"/></svg></button><button type="button" class="small-button pdf-tool-active" id="pdf-pen-tool" aria-pressed="true" title="Pen" aria-label="Pen"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m4 20 4.5-1 10.8-10.8a2.1 2.1 0 0 0-3-3L5.5 16 4 20Z"/><path d="m14.5 6.5 3 3"/></svg></button><button type="button" class="small-button" id="pdf-eraser-tool" aria-pressed="false" title="Eraser" aria-label="Eraser"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m7 21 12-12a2.8 2.8 0 0 0-4-4L3 17l4 4Z"/><path d="m9 11 4 4M11 21h10"/></svg></button></div></div></div><div class="pdf-viewer-actions"><button type="button" class="small-button pdf-viewer-save" id="pdf-viewer-save" aria-label="Save PDF" title="Save PDF"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 3h12l4 4v14H3V3h2Z"/><path d="M7 3v6h10V3M7 21v-7h10v7"/></svg></button><button type="button" class="small-button pdf-viewer-close" id="pdf-viewer-close" aria-label="Close PDF viewer" title="Close"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18"/></svg></button></div><div class="pdf-history-controls" id="pdf-history-controls" aria-label="Undo and redo"><button type="button" id="pdf-undo" aria-label="Undo" title="Undo" disabled><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 14 4 9l5-5"/><path d="M4 9h9a7 7 0 0 1 0 14h-2"/></svg></button><button type="button" id="pdf-redo" aria-label="Redo" title="Redo" disabled><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m15 14 5-5-5-5"/><path d="M20 9h-9a7 7 0 0 0 0 14h2"/></svg></button></div><button type="button" class="small-button pdf-toolbar-toggle" id="pdf-toolbar-toggle" aria-label="Hide PDF toolbar" title="Hide toolbar"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m7 14 5-5 5 5"/></svg></button></div><div class="pdf-tools-drawer" id="pdf-tools-drawer" hidden><div class="pdf-tools-drag-handle" id="pdf-tools-drag-handle" role="button" tabindex="0" aria-label="Move tool selector" title="Drag to move"><span></span><span></span><span></span><span></span><span></span><span></span></div><div class="pdf-tools-drawer-inner"><button type="button" class="small-button" id="pdf-select-drawer" aria-label="Select strokes" title="Select strokes"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 3v14l4-4 3 6 2-1-3-6h6L5 3Z"/><path d="M15 4h5v5"/></svg></button><button type="button" class="small-button pdf-tool-active" id="pdf-pen-drawer" aria-label="Pen" title="Pen"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m4 20 4.5-1 10.8-10.8a2.1 2.1 0 0 0-3-3L5.5 16 4 20Z"/><path d="m14.5 6.5 3 3"/></svg></button><button type="button" class="small-button" id="pdf-eraser-drawer" aria-label="Eraser" title="Eraser"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m7 21 12-12a2.8 2.8 0 0 0-4-4L3 17l4 4Z"/><path d="m9 11 4 4M11 21h10"/></svg></button></div></div><aside class="pdf-pen-settings" id="pdf-pen-settings" aria-label="Pen settings" hidden><div class="pdf-pen-settings-head"><strong>Pen settings</strong><button type="button" id="pdf-pen-settings-close" aria-label="Close pen settings">×</button></div><label class="pdf-pen-settings-label">Colour</label><div class="pdf-pen-colours" role="group" aria-label="Pen colour"><button type="button" class="pdf-pen-colour is-selected" data-pen-colour="#111111" aria-label="Black" title="Black"></button><button type="button" class="pdf-pen-colour" data-pen-colour="#d93025" aria-label="Red" title="Red"></button><button type="button" class="pdf-pen-colour" data-pen-colour="#1a73e8" aria-label="Blue" title="Blue"></button><button type="button" class="pdf-pen-colour" data-pen-colour="#188038" aria-label="Green" title="Green"></button><button type="button" class="pdf-pen-colour" data-pen-colour="#8e24aa" aria-label="Purple" title="Purple"></button><button type="button" class="pdf-pen-colour" data-pen-colour="#f9ab00" aria-label="Orange" title="Orange"></button></div><label class="pdf-pen-settings-label">Stroke size</label><div class="pdf-size-options" id="pdf-pen-size-options" role="group" aria-label="Stroke size"><button type="button" data-size="1" aria-label="Smallest stroke" title="1 px"><svg viewBox="0 0 32 32"><circle cx="16" cy="16" r="2" /></svg></button><button type="button" data-size="2" aria-label="Stroke size 2" title="2 px"><svg viewBox="0 0 32 32"><circle cx="16" cy="16" r="3" /></svg></button><button type="button" data-size="3" aria-label="Stroke size 3" title="3 px"><svg viewBox="0 0 32 32"><circle cx="16" cy="16" r="4.5" /></svg></button><button type="button" data-size="4" aria-label="Stroke size 4" title="4 px"><svg viewBox="0 0 32 32"><circle cx="16" cy="16" r="6" /></svg></button><button type="button" data-size="6" aria-label="Stroke size 6" title="6 px"><svg viewBox="0 0 32 32"><circle cx="16" cy="16" r="7.5" /></svg></button><button type="button" data-size="8" aria-label="Largest stroke" title="8 px"><svg viewBox="0 0 32 32"><circle cx="16" cy="16" r="9" /></svg></button></div></aside><aside class="pdf-eraser-settings pdf-pen-settings" id="pdf-eraser-settings" aria-label="Eraser settings" hidden><div class="pdf-pen-settings-head"><strong>Eraser settings</strong><button type="button" id="pdf-eraser-settings-close" aria-label="Close eraser settings">×</button></div><label class="pdf-pen-settings-label">Mode</label><div class="pdf-eraser-modes" role="group" aria-label="Eraser mode"><button type="button" class="is-selected" data-eraser-mode="stroke">Stroke</button><button type="button" data-eraser-mode="point">Point</button></div><label class="pdf-pen-settings-label">Eraser size</label><div class="pdf-size-options" id="pdf-eraser-size-options" role="group" aria-label="Eraser size"><button type="button" data-size="6" aria-label="Smallest eraser" title="6 px"><svg viewBox="0 0 32 32"><circle cx="16" cy="16" r="2" /></svg></button><button type="button" data-size="10" aria-label="Eraser size 10" title="10 px"><svg viewBox="0 0 32 32"><circle cx="16" cy="16" r="3" /></svg></button><button type="button" data-size="16" aria-label="Eraser size 16" title="16 px"><svg viewBox="0 0 32 32"><circle cx="16" cy="16" r="4.5" /></svg></button><button type="button" data-size="24" aria-label="Eraser size 24" title="24 px"><svg viewBox="0 0 32 32"><circle cx="16" cy="16" r="6" /></svg></button><button type="button" data-size="32" aria-label="Eraser size 32" title="32 px"><svg viewBox="0 0 32 32"><circle cx="16" cy="16" r="7.5" /></svg></button><button type="button" data-size="48" aria-label="Largest eraser" title="48 px"><svg viewBox="0 0 32 32"><circle cx="16" cy="16" r="9" /></svg></button></div></aside><div class="pdf-viewer-pages" id="pdf-viewer-pages"></div></div>';/* Mount the viewer at document.body so it cannot inherit Search-panel clipping, stacking, or hidden-layout state. */document.body.appendChild(shell);const pages=$("pdf-viewer-pages");pages.innerHTML='<div class="pdf-viewer-pages-content"><div class="pdf-viewer-pages-scaled">'+renderPages(data.pages||[],true)+(data.truncated?'<p class="preview-note">The preview service supplied only a subset of pages. The complete PDF can be opened in Digi.</p>':"")+'</div></div>';let closeAfterSave=false;const close=$("pdf-viewer-close");if(close)close.onclick=()=>{const hasUnsaved=[...pages.querySelectorAll(".pdf-annotation-canvas")].some(canvas=>canvas.dataset.dirty==="true");if(!hasUnsaved){shell.remove();return;}const overlay=document.createElement("div");overlay.className="pdf-unsaved-confirm-overlay";overlay.innerHTML='<div class="pdf-unsaved-confirm-card" role="dialog" aria-modal="true" aria-labelledby="pdf-unsaved-title"><strong id="pdf-unsaved-title">Careful... file is not saved</strong><div class="pdf-unsaved-confirm-actions"><button type="button" class="pdf-unsaved-discard">Don\'t save</button><button type="button" class="pdf-unsaved-save">Save &amp; close</button></div></div>';shell.appendChild(overlay);overlay.querySelector(".pdf-unsaved-discard").onclick=()=>shell.remove();overlay.querySelector(".pdf-unsaved-save").onclick=()=>{if(!save||typeof save.onclick!=="function")return;const action=overlay.querySelector(".pdf-unsaved-save");if(save.disabled)return;closeAfterSave=true;action.disabled=true;action.textContent="Saving…";save.click();if(!save.disabled){closeAfterSave=false;action.disabled=false;action.textContent="Save & close";}};};const save=$("pdf-viewer-save");if(save){const saveIcon='<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 3h12l4 4v14H3V3h2Z"/><path d="M7 3v6h10V3M7 21v-7h10v7"/></svg>';const restoreSave=()=>{save.innerHTML=saveIcon;save.disabled=false;save.classList.remove("pdf-save-loading","pdf-save-success");save.setAttribute("aria-label","Save PDF");save.title="Save PDF";};const showPdfSaveNotice=(title,message)=>{pages.querySelector(".pdf-save-notice-overlay")?.remove();const notice=document.createElement("div");notice.className="pdf-save-notice-overlay";notice.innerHTML='<div class="pdf-save-notice-card"><strong>'+esc(title)+'</strong><p>'+esc(message)+'</p><button type="button" class="ui-button" id="pdf-save-notice-ok">Okay</button></div>';pages.closest(".pdf-fullscreen-viewer").appendChild(notice);notice.querySelector("button").onclick=()=>notice.remove();};save.onclick=()=>{if(save.disabled)return;const canvases=[...pages.querySelectorAll(".pdf-annotation-canvas[data-dirty=\"true\"]")];if(!canvases.length){showPdfSaveNotice("Nothing to save","There are no new annotations to save.");return;}const overlays=canvases.map(canvas=>({page:Number(canvas.dataset.pageIndex),strokes:JSON.parse(canvas.dataset.strokes||"[]").filter(stroke=>stroke.tool==="pen")}));save.disabled=true;save.innerHTML='<span class="pdf-save-spinner" aria-hidden="true"></span>';save.classList.add("pdf-save-loading");save.setAttribute("aria-label","Saving PDF");save.title="Saving…";call("savePdfAnnotations",[path,JSON.stringify(overlays)],raw=>{const result=parseJson(raw,null,"save PDF annotations");if(!result||result.ok!==true){closeAfterSave=false;restoreSave();shell.querySelector(".pdf-unsaved-confirm-overlay")?.remove();showPdfSaveNotice("Could not save PDF",result&&result.message||"Digi could not save the annotations. Your current annotations remain available to retry.");return;}canvases.forEach(canvas=>{canvas.dataset.dirty="false";});if(closeAfterSave){closeAfterSave=false;shell.remove();showPreview(path,name,document.querySelector('.result[data-preview="' + CSS.escape(path) + '"]'));call("scan",[],()=>{refresh();});return;}showPreview(path,name,document.querySelector('.result[data-preview="' + CSS.escape(path) + '"]'));save.classList.remove("pdf-save-loading");save.classList.add("pdf-save-success");save.innerHTML='<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m5 12 4 4L19 6"/></svg>';save.setAttribute("aria-label","Saved");save.title="Saved";setTimeout(()=>{if(save.isConnected)restoreSave();},2000);});};}const select=$("pdf-select-tool"),pen=$("pdf-pen-tool"),eraser=$("pdf-eraser-tool");let annotationTool="pen";let penColor="#111111",penSize=3,eraserMode="stroke",eraserSize=18;const penSettings=$("pdf-pen-settings"),penSizeInput=$("pdf-pen-size"),penSizeValue=$("pdf-pen-size-value"),eraserSettings=$("pdf-eraser-settings"),eraserSizeInput=$("pdf-eraser-size"),eraserSizeValue=$("pdf-eraser-size-value");const penSizeOptions=$("pdf-pen-size-options"),eraserSizeOptions=$("pdf-eraser-size-options");const validSizes=(group)=>[...group.querySelectorAll("[data-size]")].map(button=>Number(button.dataset.size));const loadSavedSize=(key,fallback,group)=>{let value=fallback;try{const saved=localStorage.getItem(key);if(saved!==null&&validSizes(group).includes(Number(saved)))value=Number(saved);}catch(error){console.warn("Digi could not read saved PDF tool size.",error);}group.querySelectorAll("[data-size]").forEach(button=>button.classList.toggle("is-selected",Number(button.dataset.size)===value));return value;};penSize=loadSavedSize("digi-pdf-pen-size",3,penSizeOptions);eraserSize=loadSavedSize("digi-pdf-eraser-size",18,eraserSizeOptions);const saveToolSize=(key,value)=>{try{localStorage.setItem(key,String(value));}catch(error){console.warn("Digi could not save PDF tool size.",error);}};const bindSizeOptions=(group,key,setSize)=>group.querySelectorAll("[data-size]").forEach(button=>button.onclick=()=>{setSize(Number(button.dataset.size));group.querySelectorAll("[data-size]").forEach(item=>item.classList.toggle("is-selected",item===button));saveToolSize(key,Number(button.dataset.size));});bindSizeOptions(penSizeOptions,"digi-pdf-pen-size",value=>penSize=value);bindSizeOptions(eraserSizeOptions,"digi-pdf-eraser-size",value=>eraserSize=value);const positionToolPopup=(popup,anchor)=>{popup.style.position="fixed";popup.style.zIndex="2147483000";const rect=anchor.getBoundingClientRect(),width=popup.offsetWidth||248,height=popup.offsetHeight||180,gap=8;let left=rect.right+gap;if(left+width>window.innerWidth-8)left=rect.left-width-gap;left=Math.max(8,Math.min(window.innerWidth-width-8,left));let top=rect.top+(rect.height-height)/2;top=Math.max(8,Math.min(window.innerHeight-height-8,top));popup.style.left=left+"px";popup.style.top=top+"px";popup.style.right="auto";};const togglePenSettings=anchor=>{const opening=penSettings.hidden;penSettings.hidden=!opening;if(opening)positionToolPopup(penSettings,anchor|| (annotationTool==="pen"?drawerPen:pen));};const selectPenColour=color=>{penColor=color;penSettings.querySelectorAll("[data-pen-colour]").forEach(button=>button.classList.toggle("is-selected",button.dataset.penColour===color));};penSettings.querySelectorAll("[data-pen-colour]").forEach(button=>button.onclick=()=>selectPenColour(button.dataset.penColour));$("pdf-pen-settings-close").onclick=()=>{penSettings.hidden=true;};eraserSettings.querySelectorAll("[data-eraser-mode]").forEach(button=>button.onclick=()=>{eraserMode=button.dataset.eraserMode;eraserSettings.querySelectorAll("[data-eraser-mode]").forEach(item=>item.classList.toggle("is-selected",item.dataset.eraserMode===eraserMode));});$("pdf-eraser-settings-close").onclick=()=>{eraserSettings.hidden=true;};const toggleEraserSettings=anchor=>{const opening=eraserSettings.hidden;eraserSettings.hidden=!opening;if(opening)positionToolPopup(eraserSettings,anchor||(annotationTool==="eraser"?drawerEraser:eraser));};const closeToolPopups=()=>{penSettings.hidden=true;eraserSettings.hidden=true;};const selectTool=tool=>{closeToolPopups();if(typeof selectSettings!=="undefined")selectSettings.hidden=true;document.body.classList.toggle("pdf-pen-active",tool==="pen");annotationTool=tool;select.classList.toggle("pdf-tool-active",tool==="select");pen.classList.toggle("pdf-tool-active",tool==="pen");eraser.classList.toggle("pdf-tool-active",tool==="eraser");select.setAttribute("aria-pressed",String(tool==="select"));pen.setAttribute("aria-pressed",String(tool==="pen"));eraser.setAttribute("aria-pressed",String(tool==="eraser"));drawerSelect.classList.toggle("pdf-tool-active",tool==="select");drawerPen.classList.toggle("pdf-tool-active",tool==="pen");drawerEraser.classList.toggle("pdf-tool-active",tool==="eraser");pages.querySelectorAll(".pdf-annotation-canvas").forEach(canvas=>canvas.dataset.tool=tool);};const undoButton=$("pdf-undo"),redoButton=$("pdf-redo");let activeHistoryCanvas=null;const historyByCanvas=new WeakMap();const historyFor=canvas=>{let h=historyByCanvas.get(canvas);if(!h){let initial=[];try{initial=JSON.parse(canvas.dataset.strokes||"[]");}catch(_){}h={undo:[JSON.stringify(initial)],redo:[]};historyByCanvas.set(canvas,h);}return h;};const updateHistoryButtons=()=>{const h=activeHistoryCanvas?historyFor(activeHistoryCanvas):null;undoButton.disabled=!h||h.undo.length<2;redoButton.disabled=!h||!h.redo.length;};const rememberHistory=canvas=>{activeHistoryCanvas=canvas;const h=historyFor(canvas);let snapshot;try{snapshot=JSON.stringify(JSON.parse(canvas.dataset.strokes||"[]"));}catch(_){snapshot="[]";}if(h.undo[h.undo.length-1]!==snapshot){h.undo.push(snapshot);if(h.undo.length>100)h.undo.shift();h.redo=[];}updateHistoryButtons();};const restoreHistory=(canvas,snapshot)=>{const restored=JSON.parse(snapshot);canvas.dataset.strokes=snapshot;canvas.dataset.dirty="true";const event=new CustomEvent("digi-pdf-history-restore",{detail:{strokes:restored}});canvas.dispatchEvent(event);};undoButton.onclick=()=>{const c=activeHistoryCanvas;if(!c)return;const h=historyFor(c);let current;try{current=JSON.stringify(JSON.parse(c.dataset.strokes||"[]"));}catch(_){current="[]";}if(h.undo.length<2)return;h.redo.push(current);h.undo.pop();restoreHistory(c,h.undo[h.undo.length-1]);updateHistoryButtons();};redoButton.onclick=()=>{const c=activeHistoryCanvas;if(!c)return;const h=historyFor(c);if(!h.redo.length)return;const next=h.redo.pop();h.undo.push(next);restoreHistory(c,next);updateHistoryButtons();};let stylusEraserOverride=null;const isStylusEraserButton=event=>event.pointerType==="pen"&&(event.button===5||(event.buttons&32)!==0);const restoreStylusEraser=event=>{if(!stylusEraserOverride||(event&&event.pointerId!==undefined&&event.pointerId!==stylusEraserOverride.pointerId))return;const previous=stylusEraserOverride.previousTool;stylusEraserOverride=null;selectTool(previous);};document.addEventListener("pointerdown",event=>{if(!isStylusEraserButton(event)||stylusEraserOverride)return;stylusEraserOverride={pointerId:event.pointerId,previousTool:annotationTool};selectTool("eraser");},true);document.addEventListener("pointerup",restoreStylusEraser,true);document.addEventListener("pointercancel",restoreStylusEraser,true);document.addEventListener("lostpointercapture",restoreStylusEraser,true);select.onclick=event=>{event.preventDefault();event.stopPropagation();const wasSelect=annotationTool==="select";selectTool("select");penSettings.hidden=true;eraserSettings.hidden=true;selectSettings.hidden=wasSelect?!selectSettings.hidden:false;if(!selectSettings.hidden){const rect=select.getBoundingClientRect();selectSettings.style.left=Math.max(8,Math.min(window.innerWidth-190,rect.left))+"px";selectSettings.style.top=Math.max(8,Math.min(window.innerHeight-100,rect.bottom+8))+"px";selectSettings.style.right="auto";}};pen.onclick=()=>{if(annotationTool==="pen"){togglePenSettings(pen);}else{selectTool("pen");eraserSettings.hidden=true;}};eraser.onclick=()=>{if(annotationTool==="eraser"){toggleEraserSettings(eraser);}else{selectTool("eraser");penSettings.hidden=true;}};const drawerSelect=$("pdf-select-drawer"),drawerPen=$("pdf-pen-drawer"),drawerEraser=$("pdf-eraser-drawer"),toggle=$("pdf-toolbar-toggle"),drawer=$("pdf-tools-drawer");shell.appendChild(toggle);toggle.classList.add("pdf-shell-toggle");drawer.hidden=false;const drawerHandle=$("pdf-tools-drag-handle");let drawerDrag=null;try{const saved=JSON.parse(localStorage.getItem("digi-pdf-tools-position")||"null");if(saved&&Number.isFinite(saved.left)&&Number.isFinite(saved.top)){drawer.style.setProperty("left",Math.max(0,Math.min(innerWidth-drawer.offsetWidth,saved.left))+"px","important");drawer.style.setProperty("top",Math.max(0,Math.min(innerHeight-drawer.offsetHeight,saved.top))+"px","important");drawer.style.setProperty("right","auto","important");}}catch(_){}drawerHandle.addEventListener("pointerdown",event=>{if(event.button!==0&&event.pointerType!=="pen")return;event.preventDefault();event.stopPropagation();const rect=drawer.getBoundingClientRect();drawerDrag={id:event.pointerId,x:event.clientX,y:event.clientY,left:rect.left,top:rect.top};});window.addEventListener("pointermove",event=>{if(!drawerDrag||event.pointerId!==drawerDrag.id)return;event.preventDefault();const rect=drawer.getBoundingClientRect();const left=Math.max(4,Math.min(window.innerWidth-rect.width-4,drawerDrag.left+event.clientX-drawerDrag.x));const top=Math.max(4,Math.min(window.innerHeight-rect.height-4,drawerDrag.top+event.clientY-drawerDrag.y));drawer.style.setProperty("left",left+"px","important");drawer.style.setProperty("top",top+"px","important");drawer.style.setProperty("right","auto","important");},{capture:true});const finishDrawerDrag=event=>{if(!drawerDrag||(event&&event.pointerId!==undefined&&event.pointerId!==drawerDrag.id))return;drawerDrag=null;const rect=drawer.getBoundingClientRect();try{localStorage.setItem("digi-pdf-tools-position",JSON.stringify({left:rect.left,top:rect.top}));}catch(_){}};window.addEventListener("pointerup",finishDrawerDrag,true);window.addEventListener("pointercancel",finishDrawerDrag,true);drawerHandle.addEventListener("keydown",event=>{if(event.key==="ArrowLeft"||event.key==="ArrowRight"||event.key==="ArrowUp"||event.key==="ArrowDown"){event.preventDefault();const rect=drawer.getBoundingClientRect(),step=10;drawer.style.left=Math.max(4,Math.min(innerWidth-rect.width-4,rect.left+(event.key==="ArrowLeft"?-step:event.key==="ArrowRight"?step:0)))+"px";drawer.style.top=Math.max(4,Math.min(innerHeight-rect.height-4,rect.top+(event.key==="ArrowUp"?-step:event.key==="ArrowDown"?step:0)))+"px";drawer.style.right="auto";finishDrawerDrag();}});const syncTools=()=>{drawerSelect.classList.toggle("pdf-tool-active",annotationTool==="select");drawerPen.classList.toggle("pdf-tool-active",annotationTool==="pen");drawerEraser.classList.toggle("pdf-tool-active",annotationTool==="eraser");};drawerSelect.onclick=event=>{event.preventDefault();event.stopPropagation();const wasSelect=annotationTool==="select";selectTool("select");penSettings.hidden=true;eraserSettings.hidden=true;selectSettings.hidden=wasSelect?!selectSettings.hidden:false;if(!selectSettings.hidden){const rect=drawerSelect.getBoundingClientRect();selectSettings.style.left=Math.max(8,Math.min(window.innerWidth-190,rect.left))+"px";selectSettings.style.top=Math.max(8,Math.min(window.innerHeight-100,rect.bottom+8))+"px";selectSettings.style.right="auto";}syncTools();};drawerPen.onclick=()=>{if(annotationTool==="pen"){togglePenSettings(drawerPen);}else{selectTool("pen");}syncTools();};drawerEraser.onclick=()=>{if(annotationTool==="eraser"){toggleEraserSettings(drawerEraser);}else{selectTool("eraser");penSettings.hidden=true;}syncTools();};const toggleParent=toggle.parentElement;const historyControls=shell.querySelector("#pdf-history-controls");const historyParent=historyControls&&historyControls.parentElement;let nativeFullscreenToggled=false;toggle.onclick=()=>{const viewer=pages.closest(".pdf-fullscreen-viewer");const collapsed=viewer.classList.toggle("pdf-toolbar-collapsed");shell.classList.toggle("pdf-chrome-hidden",collapsed);if(collapsed){shell.appendChild(toggle);if(historyControls)shell.appendChild(historyControls);if(backend&&typeof backend.toggleFullscreenWindow==="function"){backend.toggleFullscreenWindow();nativeFullscreenToggled=true;}}else{if(toggleParent)toggleParent.appendChild(toggle);if(historyControls&&historyParent)historyParent.appendChild(historyControls);if(nativeFullscreenToggled&&backend&&typeof backend.toggleFullscreenWindow==="function"){backend.toggleFullscreenWindow();nativeFullscreenToggled=false;}}toggle.setAttribute("aria-label",collapsed?"Show PDF controls":"Hide PDF controls");toggle.title=collapsed?"Show controls":"Hide controls";toggle.innerHTML=collapsed?'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m7 10 5 5 5-5"/></svg>':'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m7 14 5-5 5 5"/></svg>';drawer.hidden=false;};/* OneNote-style pinch zoom: the point between the fingers remains fixed as scale changes. */
const gestureSurface=pages;gestureSurface.style.touchAction="none";let gesture=null,viewScale=1,viewX=0,viewY=0;
const pageContent=pages.querySelector(".pdf-viewer-pages-content");
const pageStack=pages.querySelector(".pdf-viewer-pages-scaled");
const applyPdfView=()=>{if(!pageContent||!pageStack)return;pageStack.style.transformOrigin="0 0";pageStack.style.transform="translate("+viewX+"px, "+viewY+"px) scale("+viewScale+")";pageContent.style.height=(pageStack.offsetHeight*viewScale)+"px";if(typeof redrawOutsideInk==="function")redrawOutsideInk();};
const touchPoint=e=>({x:e.clientX,y:e.clientY});
const touchDistance=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
/* Recover the stack's untransformed client-space origin. This avoids feeding the scaled bounding box back into the next zoom calculation. */
const untransformedStackOrigin=()=>{const r=pageContent.getBoundingClientRect();return{x:r.left,y:r.top};};
const captureZoomAnchor=point=>{const origin=untransformedStackOrigin();return{x:(point.x-origin.x-viewX)/viewScale,y:(point.y-origin.y-viewY)/viewScale};};
const applyZoomAt=(scale,point)=>{const origin=untransformedStackOrigin();viewScale=scale;viewX=point.x-origin.x-gesture.anchor.x*scale;viewY=point.y-origin.y-gesture.anchor.y*scale;};
gestureSurface.addEventListener("pointerdown",e=>{if(e.pointerType!=="touch")return;e.preventDefault();if(!gesture)gesture={startX:e.clientX,startY:e.clientY,baseX:viewX,baseY:viewY,points:new Map()};gesture.points.set(e.pointerId,touchPoint(e));if(gesture.points.size===2){const pts=Array.from(gesture.points.values()),mid={x:(pts[0].x+pts[1].x)/2,y:(pts[0].y+pts[1].y)/2};gesture.startDistance=touchDistance(pts[0],pts[1]);gesture.startScale=viewScale;gesture.anchor=captureZoomAnchor(mid);}try{gestureSurface.setPointerCapture(e.pointerId);}catch(_){}});
gestureSurface.addEventListener("pointermove",e=>{if(e.pointerType!=="touch"||!gesture||!gesture.points.has(e.pointerId))return;e.preventDefault();gesture.points.set(e.pointerId,touchPoint(e));const pts=Array.from(gesture.points.values());if(pts.length>=2){const mid={x:(pts[0].x+pts[1].x)/2,y:(pts[0].y+pts[1].y)/2},d=touchDistance(pts[0],pts[1]);if(!gesture.startDistance){gesture.startDistance=d;gesture.startScale=viewScale;gesture.anchor=captureZoomAnchor(mid);}const nextScale=Math.max(.5,Math.min(4,gesture.startScale*d/Math.max(1,gesture.startDistance)));/* Keep the actual pinch midpoint as the target for both zoom-in and zoom-out, like Journal/OneNote. */applyZoomAt(nextScale,mid);}else{viewX=gesture.baseX+(e.clientX-gesture.startX);viewY=gesture.baseY+(e.clientY-gesture.startY);}applyPdfView();});
const endTouch=e=>{if(e.pointerType!=="touch"||!gesture)return;gesture.points.delete(e.pointerId);if(!gesture.points.size)gesture=null;else{const p=Array.from(gesture.points.values())[0];gesture.startX=p.x;gesture.startY=p.y;gesture.baseX=viewX;gesture.baseY=viewY;gesture.startDistance=0;gesture.startScale=viewScale;}};
gestureSurface.addEventListener("pointerup",endTouch);gestureSurface.addEventListener("pointercancel",endTouch);gestureSurface.addEventListener("lostpointercapture",endTouch);
/* Outside-page ink uses the fullscreen shell as its event surface (not the smaller pages viewport), while its transparent canvas draws white ink over the black workspace. The scratch layer is attached directly to document.body, outside the transformed viewer, so existing marks remain fixed to viewport positions as the PDF pans or zooms. */
const outsideInkCanvas=document.createElement("canvas");outsideInkCanvas.className="pdf-outside-ink-canvas";outsideInkCanvas.setAttribute("aria-label","Scratch ink outside PDF pages");shell.appendChild(outsideInkCanvas);
const outsideInkCtx=outsideInkCanvas.getContext("2d");let outsideStrokes=[],outsideInkDrawing=false,outsideInkPointer=null,outsideInkLast=null,outsideSelectedStroke=null,outsideCurrentStroke=null,outsideMoveStart=null;
const outsideInkResize=()=>{const dpr=Math.max(1,Math.min(2,window.devicePixelRatio||1)),w=Math.max(1,Math.round(window.innerWidth*dpr)),h=Math.max(1,Math.round(window.innerHeight*dpr));if(outsideInkCanvas.width!==w||outsideInkCanvas.height!==h){outsideInkCanvas.width=w;outsideInkCanvas.height=h;}outsideInkCanvas.style.left="0px";outsideInkCanvas.style.top="0px";outsideInkCanvas.style.width="100vw";outsideInkCanvas.style.height="100vh";outsideInkCtx.setTransform(dpr,0,0,dpr,0,0);redrawOutsideInk();};
const outsideInkPoint=e=>({x:(e.clientX-viewX)/viewScale,y:(e.clientY-viewY)/viewScale,pressure:Number.isFinite(e.pressure)&&e.pressure>0?Math.max(.08,Math.min(1,e.pressure)):.5});
const outsideInkToScreen=p=>({x:p.x*viewScale+viewX,y:p.y*viewScale+viewY,pressure:p.pressure});
const outsideInkWidth=p=>Math.max(.8,2.6*(.12+Math.pow(p.pressure,1.65)*.88));
const outsideInkSegment=(ctx,a,b,color="#fff",sizeFn=outsideInkWidth)=>{const dx=b.x-a.x,dy=b.y-a.y,len=Math.hypot(dx,dy)||1,nx=-dy/len,ny=dx/len,ra=sizeFn(a)/2,rb=sizeFn(b)/2;ctx.fillStyle=color;ctx.beginPath();ctx.moveTo(a.x+nx*ra,a.y+ny*ra);ctx.lineTo(b.x+nx*rb,b.y+ny*rb);ctx.lineTo(b.x-nx*rb,b.y-ny*rb);ctx.lineTo(a.x-nx*ra,a.y-ny*ra);ctx.closePath();ctx.fill();ctx.beginPath();ctx.arc(a.x,a.y,ra,0,Math.PI*2);ctx.fill();ctx.beginPath();ctx.arc(b.x,b.y,rb,0,Math.PI*2);ctx.fill();};
const redrawOutsideInk=()=>{if(!outsideInkCtx)return;const dpr=outsideInkCanvas.width/Math.max(1,window.innerWidth);outsideInkCtx.setTransform(dpr,0,0,dpr,0,0);outsideInkCtx.clearRect(0,0,window.innerWidth,window.innerHeight);for(const stroke of outsideStrokes){const selected=stroke===outsideSelectedStroke,color=selected?"#8ab4ff":"#fff",sizeFn=p=>outsideInkWidth(p)+(selected?3:0),points=stroke.points.map(outsideInkToScreen);if(points.length===1){const p=points[0];outsideInkCtx.fillStyle=color;outsideInkCtx.beginPath();outsideInkCtx.arc(p.x,p.y,sizeFn(p)/2,0,Math.PI*2);outsideInkCtx.fill();}for(let i=1;i<points.length;i++)outsideInkSegment(outsideInkCtx,points[i-1],points[i],points[i].inkColor||color,sizeFn);}};
const isOutsidePdfPage=e=>{const target=document.elementFromPoint(e.clientX,e.clientY)||e.target;return !(target instanceof Element&&target.closest(".pdf-page-annotatable,.pdf-page"));};
const outsideStrokeDistance=(stroke,p)=>{let best=Infinity;for(let i=0;i<stroke.points.length;i++){const a=stroke.points[i];best=Math.min(best,Math.hypot(p.x-a.x,p.y-a.y));if(i){const b=stroke.points[i-1],dx=a.x-b.x,dy=a.y-b.y,l=dx*dx+dy*dy,t=l?Math.max(0,Math.min(1,((p.x-b.x)*dx+(p.y-b.y)*dy)/l)):0;best=Math.min(best,Math.hypot(p.x-(b.x+t*dx),p.y-(b.y+t*dy)));}}return best;};
document.addEventListener("pointerdown",e=>{if(e.pointerType!=="pen"||!isOutsidePdfPage(e)||!["pen","select","eraser"].includes(annotationTool))return;const point=outsideInkPoint(e);outsideInkDrawing=true;outsideInkPointer=e.pointerId;outsideInkLast=point;
if(annotationTool==="pen"){outsideSelectedStroke=null;outsideCurrentStroke={points:[point]};outsideStrokes.push(outsideCurrentStroke);}
else if(annotationTool==="eraser"){outsideStrokes=outsideStrokes.filter(stroke=>outsideStrokeDistance(stroke,point)>12);if(outsideSelectedStroke&&!outsideStrokes.includes(outsideSelectedStroke))outsideSelectedStroke=null;}
else{outsideSelectedStroke=[...outsideStrokes].reverse().find(stroke=>outsideStrokeDistance(stroke,point)<14)||null;outsideMoveStart=point;}
redrawOutsideInk();try{pages.setPointerCapture(e.pointerId);}catch(_){}e.preventDefault();e.stopPropagation();},true);
/* Track pen strokes that begin on a PDF page so they can seamlessly continue onto the black workspace. */
let bridgeInk=null;
const isPdfPoint=(x,y)=>{const target=document.elementFromPoint(x,y);return !!(target instanceof Element&&target.closest(".pdf-page-annotatable,.pdf-page"));};
document.addEventListener("pointerdown",e=>{if(e.pointerType!=="pen"||!isPdfPoint(e.clientX,e.clientY)||annotationTool!=="pen")return;bridgeInk={pointerId:e.pointerId,points:[{...outsideInkPoint(e),inkColor:"#111"}],bridging:false};},true);
document.addEventListener("pointermove",e=>{if(!bridgeInk||e.pointerId!==bridgeInk.pointerId||outsideInkDrawing)return;const samples=typeof e.getCoalescedEvents==="function"?e.getCoalescedEvents():[e];for(const sample of samples){const point=outsideInkPoint(sample),inside=isPdfPoint(sample.clientX,sample.clientY);point.inkColor=inside?"#111":"#fff";bridgeInk.points.push(point);if(!inside&&!bridgeInk.bridging){bridgeInk.bridging=true;outsideInkDrawing=true;outsideInkPointer=e.pointerId;outsideSelectedStroke=null;outsideCurrentStroke={points:bridgeInk.points.slice()};outsideStrokes.push(outsideCurrentStroke);redrawOutsideInk();}else if(bridgeInk.bridging&&outsideCurrentStroke){const prev=outsideCurrentStroke.points[outsideCurrentStroke.points.length-1],dpr=outsideInkCanvas.width/Math.max(1,window.innerWidth),a=outsideInkToScreen(prev),b=outsideInkToScreen(point);outsideInkCtx.setTransform(dpr,0,0,dpr,0,0);outsideInkCtx.strokeStyle=point.inkColor;outsideInkCtx.lineWidth=2.2;outsideInkCtx.lineCap="round";outsideInkCtx.lineJoin="round";outsideInkCtx.beginPath();outsideInkCtx.moveTo(a.x,a.y);outsideInkCtx.lineTo(b.x,b.y);outsideInkCtx.stroke();outsideCurrentStroke.points.push(point);}}},true);
const finishBridgeInk=e=>{if(!bridgeInk||e.pointerId!==bridgeInk.pointerId)return;if(bridgeInk.bridging){outsideInkDrawing=false;outsideInkPointer=null;outsideInkLast=null;outsideCurrentStroke=null;outsideMoveStart=null;}bridgeInk=null;};
document.addEventListener("pointerup",finishBridgeInk,true);document.addEventListener("pointercancel",finishBridgeInk,true);
document.addEventListener("pointermove",e=>{if(bridgeInk?.bridging)return;if(!outsideInkDrawing||e.pointerId!==outsideInkPointer)return;const samples=typeof e.getCoalescedEvents==="function"?e.getCoalescedEvents():[e];if(annotationTool==="pen"&&outsideCurrentStroke){const dpr=outsideInkCanvas.width/Math.max(1,window.innerWidth);outsideInkCtx.setTransform(dpr,0,0,dpr,0,0);outsideInkCtx.strokeStyle="#fff";outsideInkCtx.lineWidth=2.2;outsideInkCtx.lineCap="round";outsideInkCtx.lineJoin="round";for(const sample of samples){const point=outsideInkPoint(sample),prev=outsideCurrentStroke.points[outsideCurrentStroke.points.length-1],a=outsideInkToScreen(prev),b=outsideInkToScreen(point);outsideInkCtx.beginPath();outsideInkCtx.moveTo(a.x,a.y);outsideInkCtx.lineTo(b.x,b.y);outsideInkCtx.stroke();outsideCurrentStroke.points.push(point);outsideInkLast=point;}}else{for(const sample of samples){const point=outsideInkPoint(sample);if(annotationTool==="eraser"){outsideStrokes=outsideStrokes.filter(stroke=>outsideStrokeDistance(stroke,point)>12);if(outsideSelectedStroke&&!outsideStrokes.includes(outsideSelectedStroke))outsideSelectedStroke=null;}else if(annotationTool==="select"&&outsideSelectedStroke&&outsideMoveStart){const dx=point.x-outsideMoveStart.x,dy=point.y-outsideMoveStart.y;for(const p of outsideSelectedStroke.points){p.x+=dx;p.y+=dy;}outsideMoveStart=point;}outsideInkLast=point;}redrawOutsideInk();}e.preventDefault();e.stopPropagation();},true);
const stopOutsideInk=e=>{if(!outsideInkDrawing||e.pointerId!==outsideInkPointer)return;outsideInkDrawing=false;outsideInkPointer=null;outsideInkLast=null;outsideCurrentStroke=null;outsideMoveStart=null;};
document.addEventListener("pointerup",stopOutsideInk,true);document.addEventListener("pointercancel",stopOutsideInk,true);document.addEventListener("lostpointercapture",stopOutsideInk,true);
shell.addEventListener("keydown",e=>{if((e.key==="Delete"||e.key==="Backspace")&&outsideSelectedStroke&&shell.isConnected){e.preventDefault();outsideStrokes=outsideStrokes.filter(stroke=>stroke!==outsideSelectedStroke);outsideSelectedStroke=null;redrawOutsideInk();}});
const redrawWorkspaceInk=()=>redrawOutsideInk();
window.addEventListener("resize",outsideInkResize);outsideInkResize();
pages.querySelectorAll(".pdf-page").forEach(page=>{const img=page.querySelector("img");if(!img)return;const wrap=document.createElement("div");wrap.className="pdf-page-annotatable";img.parentNode.insertBefore(wrap,img);wrap.appendChild(img);const canvas=document.createElement("canvas");canvas.tabIndex=0;canvas.className="pdf-annotation-canvas";canvas.dataset.tool=annotationTool;canvas.dataset.pageIndex=String(Number((img.alt.match(/Page\s+(\d+)/i)||[])[1]||1)-1);canvas.dataset.dirty="false";canvas.setAttribute("aria-label","Annotations for "+img.alt);wrap.appendChild(canvas);let strokes=[];try{strokes=JSON.parse(img.dataset.annotations||"[]");}catch(_){}const inkWidth=(point,size=3)=>{const pressure=Number.isFinite(point[2])?Math.max(0,Math.min(1,point[2])):0.5;return Math.max(0.35,size*(0.12+Math.pow(pressure,1.65)*0.88));};const drawSmoothStroke=(ctx,points,width,height,color="#111111",size=3)=>{if(!points.length)return;const xy=p=>[p[0]*width,p[1]*height];ctx.fillStyle=color;if(points.length===1){const p=xy(points[0]);ctx.beginPath();ctx.arc(p[0],p[1],inkWidth(points[0],size)/2,0,Math.PI*2);ctx.fill();return;}const samples=[];for(let i=0;i<points.length-1;i++){const a=points[i],b=points[i+1],pa=xy(a),pb=xy(b),steps=Math.max(1,Math.ceil(Math.hypot(pb[0]-pa[0],pb[1]-pa[1])/.8));for(let j=0;j<steps;j++){const t=j/steps;samples.push({x:pa[0]+(pb[0]-pa[0])*t,y:pa[1]+(pb[1]-pa[1])*t,r:inkWidth(a,size)/2+(inkWidth(b,size)/2-inkWidth(a,size)/2)*t});}}const last=points[points.length-1],lp=xy(last);samples.push({x:lp[0],y:lp[1],r:inkWidth(last,size)/2});const left=[],right=[];for(let i=0;i<samples.length;i++){const p=samples[i],before=samples[Math.max(0,i-1)],after=samples[Math.min(samples.length-1,i+1)],dx=after.x-before.x,dy=after.y-before.y,len=Math.hypot(dx,dy)||1,nx=-dy/len,ny=dx/len;left.push([p.x+nx*p.r,p.y+ny*p.r]);right.push([p.x-nx*p.r,p.y-ny*p.r]);}ctx.beginPath();ctx.moveTo(left[0][0],left[0][1]);for(let i=1;i<left.length;i++)ctx.lineTo(left[i][0],left[i][1]);for(let i=right.length-1;i>=0;i--)ctx.lineTo(right[i][0],right[i][1]);ctx.closePath();ctx.fill();ctx.beginPath();ctx.arc(samples[0].x,samples[0].y,samples[0].r,0,Math.PI*2);ctx.arc(lp[0],lp[1],inkWidth(last)/2,0,Math.PI*2);ctx.fill();};const drawInkSegments=(ctx,points,width,height,color="#111111",size=3)=>{if(points.length<2)return;ctx.fillStyle=color;for(let i=1;i<points.length;i++){const a=points[i-1],b=points[i],ax=a[0]*width,ay=a[1]*height,bx=b[0]*width,by=b[1]*height,dx=bx-ax,dy=by-ay,len=Math.hypot(dx,dy);if(len<.01)continue;const nx=-dy/len,ny=dx/len,ra=inkWidth(a,size)/2,rb=inkWidth(b,size)/2;ctx.beginPath();ctx.moveTo(ax+nx*ra,ay+ny*ra);ctx.lineTo(bx+nx*rb,by+ny*rb);ctx.lineTo(bx-nx*rb,by-ny*rb);ctx.lineTo(ax-nx*ra,ay-ny*ra);ctx.closePath();ctx.fill();ctx.beginPath();ctx.arc(ax,ay,ra,0,Math.PI*2);ctx.fill();ctx.beginPath();ctx.arc(bx,by,rb,0,Math.PI*2);ctx.fill();}};const drawInkSegment=(ctx,a,b,width,height,color="#111111",size=3)=>drawInkSegments(ctx,[a,b],width,height,color,size);let selectionRect=null,selectionMode="square",selectionPath=[];const selectedStrokes=new Set();let moveMode=false,moveStart=null;const selectionActions=document.createElement("div");selectionActions.className="pdf-selection-actions";selectionActions.hidden=true;selectionActions.setAttribute("role","toolbar");selectionActions.setAttribute("aria-label","Selected stroke actions");selectionActions.innerHTML='<button type="button" data-selection-action="delete">Delete</button><button type="button" data-selection-action="cut">Cut</button><button type="button" data-selection-action="copy">Copy</button>';wrap.appendChild(selectionActions);const selectSettings=document.createElement("div");selectSettings.className="pdf-select-settings pdf-pen-settings";selectSettings.hidden=true;selectSettings.innerHTML='<div class="pdf-pen-settings-head"><strong>Select mode</strong></div><div class="pdf-select-modes" role="group" aria-label="Selection mode"><button type="button" data-select-mode="lasso">Lasso</button><button type="button" data-select-mode="square" class="is-selected">Square</button></div>';document.body.appendChild(selectSettings);selectSettings.style.position="fixed";selectSettings.style.zIndex="2147483000";const openSelectSettings=anchor=>{const wasAlreadySelect=annotationTool==="select";if(!wasAlreadySelect){selectTool("select");selectSettings.hidden=true;}else{selectSettings.hidden=!selectSettings.hidden;}penSettings.hidden=true;eraserSettings.hidden=true;if(!selectSettings.hidden){positionToolPopup(selectSettings,anchor);}};select.onclick=event=>{event.preventDefault();event.stopPropagation();openSelectSettings(select);};drawerSelect.onclick=event=>{event.preventDefault();event.stopPropagation();openSelectSettings(drawerSelect);syncTools();};selectSettings.querySelectorAll("[data-select-mode]").forEach(button=>button.addEventListener("click",()=>{selectionMode=button.dataset.selectMode;selectSettings.querySelectorAll("[data-select-mode]").forEach(item=>item.classList.toggle("is-selected",item.dataset.selectMode===selectionMode));selectSettings.hidden=true;}));const pasteMenu=document.createElement("div");pasteMenu.className="pdf-paste-menu";pasteMenu.hidden=true;pasteMenu.innerHTML='<button type="button" data-paste-strokes>Paste</button>';const pasteMenuHost=canvas.closest(".pdf-fullscreen-shell")||document.body;pasteMenuHost.appendChild(pasteMenu);const copyButton=selectionActions.querySelector('[data-selection-action="copy"]');let pastePoint=null;const positionSelectionActions=()=>{if(selectionActions.hidden||!selectedStrokes.size)return;const width=canvas.clientWidth,height=canvas.clientHeight;let left=1,top=1,right=0;for(const stroke of selectedStrokes)for(const p of stroke.points){left=Math.min(left,p[0]);top=Math.min(top,p[1]);right=Math.max(right,p[0]);}const barWidth=selectionActions.offsetWidth||240,barHeight=selectionActions.offsetHeight||38;selectionActions.style.left=Math.max(4,Math.min(width-barWidth-4,((left+right)/2)*width-barWidth/2))+"px";selectionActions.style.right="auto";selectionActions.style.top=Math.max(4,top*height-barHeight-10)+"px";};const pasteStrokes=()=>{if(!sharedStrokeClipboard.length)return;const sourcePoints=sharedStrokeClipboard.flatMap(stroke=>stroke.points);if(!sourcePoints.length)return;const minX=Math.min(...sourcePoints.map(p=>p[0])),maxX=Math.max(...sourcePoints.map(p=>p[0])),minY=Math.min(...sourcePoints.map(p=>p[1])),maxY=Math.max(...sourcePoints.map(p=>p[1]));const anchor=pastePoint||[(minX+maxX)/2,(minY+maxY)/2];const dx=anchor[0]-(minX+maxX)/2,dy=anchor[1]-(minY+maxY)/2;const pasted=sharedStrokeClipboard.map(stroke=>({...stroke,points:stroke.points.map(p=>[Math.max(0,Math.min(1,p[0]+dx)),Math.max(0,Math.min(1,p[1]+dy)),...p.slice(2)])}));pasted.forEach(stroke=>strokes.push(stroke));pastePoint=null;selectedStrokes.clear();pasted.forEach(stroke=>selectedStrokes.add(stroke));selectionActions.hidden=false;copyButton.disabled=false;canvas.dataset.dirty="true";canvas.dataset.strokes=JSON.stringify(strokes);pasteMenu.hidden=true;redraw();positionSelectionActions();};pasteMenu.querySelector("[data-paste-strokes]").addEventListener("click",pasteStrokes);const showPasteMenu=event=>{if(!sharedStrokeClipboard.length)return;event.preventDefault();event.stopPropagation();const canvasRect=canvas.getBoundingClientRect();pastePoint=[Math.max(0,Math.min(1,(event.clientX-canvasRect.left)/Math.max(1,canvasRect.width))),Math.max(0,Math.min(1,(event.clientY-canvasRect.top)/Math.max(1,canvasRect.height)))];pasteMenu.style.position="fixed";pasteMenu.style.left="0px";pasteMenu.style.top="0px";pasteMenu.hidden=false;const menuRect=pasteMenu.getBoundingClientRect(),gap=12;let left=event.clientX+gap,top=event.clientY+gap;if(left+menuRect.width>window.innerWidth-8)left=event.clientX-menuRect.width-gap;if(top+menuRect.height>window.innerHeight-8)top=event.clientY-menuRect.height-gap;pasteMenu.style.left=Math.max(8,Math.min(window.innerWidth-menuRect.width-8,left))+"px";pasteMenu.style.top=Math.max(8,Math.min(window.innerHeight-menuRect.height-8,top))+"px";};let stylusHold=null,lastStylusTap=null;canvas.addEventListener("contextmenu",showPasteMenu);wrap.addEventListener("contextmenu",showPasteMenu);canvas.addEventListener("pointerdown",event=>{if(event.pointerType!=="pen"||event.button!==0||annotationTool!=="select"||!sharedStrokeClipboard.length)return;const now=performance.now();if(lastStylusTap&&now-lastStylusTap.time<420&&Math.hypot(event.clientX-lastStylusTap.x,event.clientY-lastStylusTap.y)<28){lastStylusTap=null;clearStylusHold(event);event.preventDefault();event.stopImmediatePropagation();showPasteMenu(event);return;}lastStylusTap={time:now,x:event.clientX,y:event.clientY};setTimeout(()=>{if(lastStylusTap&&performance.now()-lastStylusTap.time>=420)lastStylusTap=null;},430);},true);canvas.addEventListener("pointerdown",event=>{if(event.pointerType!=="pen"||!sharedStrokeClipboard.length)return;if(event.button===2){showPasteMenu(event);return;}if(event.button===0){stylusHold={id:event.pointerId,x:event.clientX,y:event.clientY};stylusHold.timer=setTimeout(()=>{if(!stylusHold)return;if(currentStroke&&currentStroke.tool==="pen"){strokes=strokes.filter(stroke=>stroke!==currentStroke);drawing=false;currentStroke=null;canvas.dataset.strokes=JSON.stringify(strokes);redraw();}const held={clientX:stylusHold.x,clientY:stylusHold.y,preventDefault(){},stopPropagation(){}};showPasteMenu(held);stylusHold=null;},550);}},true);canvas.addEventListener("pointermove",event=>{if(!stylusHold||stylusHold.id!==event.pointerId)return;if(Math.hypot(event.clientX-stylusHold.x,event.clientY-stylusHold.y)>8){clearTimeout(stylusHold.timer);stylusHold=null;}},true);const clearStylusHold=event=>{if(!stylusHold||(event&&stylusHold.id!==event.pointerId))return;clearTimeout(stylusHold.timer);stylusHold=null;};canvas.addEventListener("pointerup",clearStylusHold,true);canvas.addEventListener("pointercancel",clearStylusHold,true);const redraw=()=>{const width=canvas.clientWidth,height=canvas.clientHeight;if(!width||!height)return;const inkPixelRatio=6;const w=Math.round(width*inkPixelRatio),h=Math.round(height*inkPixelRatio);if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h;}const ctx=canvas.getContext("2d");ctx.setTransform(inkPixelRatio,0,0,inkPixelRatio,0,0);ctx.clearRect(0,0,width,height);for(const stroke of strokes){if(stroke.tool!=="pen"||!stroke.points.length)continue;if(selectedStrokes.has(stroke))drawSmoothStroke(ctx,stroke.points,width,height,"#4285f4",(Number(stroke.size)||3)+5);drawSmoothStroke(ctx,stroke.points,width,height,stroke.color||"#111111",Number(stroke.size)||3);}if(selectionRect){ctx.fillStyle="rgba(66,133,244,.12)";ctx.strokeStyle="#4285f4";ctx.lineWidth=1.5;ctx.setLineDash([5,3]);ctx.fillRect(selectionRect.left*width,selectionRect.top*height,(selectionRect.right-selectionRect.left)*width,(selectionRect.bottom-selectionRect.top)*height);ctx.strokeRect(selectionRect.left*width,selectionRect.top*height,(selectionRect.right-selectionRect.left)*width,(selectionRect.bottom-selectionRect.top)*height);ctx.setLineDash([]);}if(selectionPath.length>1){ctx.save();ctx.beginPath();ctx.moveTo(selectionPath[0][0]*width,selectionPath[0][1]*height);for(let i=1;i<selectionPath.length;i++)ctx.lineTo(selectionPath[i][0]*width,selectionPath[i][1]*height);ctx.closePath();ctx.fillStyle="rgba(66,133,244,.12)";ctx.strokeStyle="#4285f4";ctx.lineWidth=1.5;ctx.setLineDash([5,3]);ctx.fill();ctx.stroke();ctx.restore();}};const drawDot=point=>{const width=canvas.clientWidth,height=canvas.clientHeight,ctx=canvas.getContext("2d");ctx.fillStyle=currentStroke?.color||"#111111";ctx.beginPath();ctx.arc(point[0]*width,point[1]*height,inkWidth(point,currentStroke?.size||3)/2,0,Math.PI*2);ctx.fill();};const drawSegment=points=>{if(points.length<2)return;const width=canvas.clientWidth,height=canvas.clientHeight,ctx=canvas.getContext("2d");drawInkSegments(ctx,points,width,height,currentStroke?.color||"#111111",currentStroke?.size||3);};canvas.dataset.strokes=JSON.stringify(strokes);canvas.addEventListener("pointerdown",()=>{activeHistoryCanvas=canvas;rememberHistory(canvas);},{capture:true});canvas.addEventListener("pointerup",()=>{activeHistoryCanvas=canvas;rememberHistory(canvas);});canvas.addEventListener("click",()=>{activeHistoryCanvas=canvas;updateHistoryButtons();});selectionActions.addEventListener("click",()=>{activeHistoryCanvas=canvas;rememberHistory(canvas);});pasteMenu.addEventListener("click",()=>{activeHistoryCanvas=canvas;rememberHistory(canvas);});canvas.addEventListener("digi-pdf-history-restore",event=>{strokes=event.detail.strokes;selectedStrokes.clear();selectionActions.hidden=true;currentStroke=null;drawing=false;redraw();});const setup=()=>redraw();if(img.complete)setup();else img.addEventListener("load",setup,{once:true});const resizeObserver=new ResizeObserver(setup);resizeObserver.observe(img);let drawing=false,currentStroke=null;const pointFromEvent=event=>{const r=canvas.getBoundingClientRect();return[Math.max(0,Math.min(1,(event.clientX-r.left)/r.width)),Math.max(0,Math.min(1,(event.clientY-r.top)/r.height)),Number.isFinite(event.pressure)?Math.max(0,Math.min(1,event.pressure)):0.5];};const distanceToSegment=(p,a,b)=>{const dx=b[0]-a[0],dy=b[1]-a[1],length=dx*dx+dy*dy;if(!length)return Math.hypot(p[0]-a[0],p[1]-a[1]);const t=Math.max(0,Math.min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/length));return Math.hypot(p[0]-(a[0]+t*dx),p[1]-(a[1]+t*dy));};let pendingInkPoints=[],inkFrame=0;const flushInk=()=>{inkFrame=0;if(!pendingInkPoints.length||!currentStroke)return;const points=pendingInkPoints;pendingInkPoints=[];drawSegment(points);};const scheduleInkFlush=()=>{if(!inkFrame)inkFrame=requestAnimationFrame(flushInk);};const normalizeRect=(a,b)=>({left:Math.min(a[0],b[0]),top:Math.min(a[1],b[1]),right:Math.max(a[0],b[0]),bottom:Math.max(a[1],b[1])});const segmentHitsRect=(a,b,r)=>{let t0=0,t1=1,dx=b[0]-a[0],dy=b[1]-a[1];for(const [p,q] of [[-dx,a[0]-r.left],[dx,r.right-a[0]],[-dy,a[1]-r.top],[dy,r.bottom-a[1]]]){if(Math.abs(p)<1e-12){if(q<0)return false;}else{const t=q/p;if(p<0){if(t>t1)return false;if(t>t0)t0=t;}else{if(t<t0)return false;if(t<t1)t1=t;}}}return true;};const strokeHitsRect=(stroke,r)=>{for(let i=0;i<stroke.points.length;i++){const p=stroke.points[i];if(p[0]>=r.left&&p[0]<=r.right&&p[1]>=r.top&&p[1]<=r.bottom)return true;if(i&&segmentHitsRect(stroke.points[i-1],p,r))return true;}return false;};canvas.addEventListener("pointerdown",event=>{if(event.pointerType==="touch")return;event.preventDefault();const point=pointFromEvent(event);if(annotationTool==="select"){pasteMenu.hidden=true;if(selectedStrokes.size){const hitSelected=[...selectedStrokes].some(stroke=>stroke.points.some((p,i)=>{if(Math.hypot(p[0]-point[0],p[1]-point[1])<.018)return true;return i>0&&distanceToSegment(point,stroke.points[i-1],p)<.012;}));if(hitSelected){drawing=true;moveStart=point;currentStroke={tool:"move",points:[point]};try{canvas.setPointerCapture(event.pointerId);}catch(_){}return;}}selectedStrokes.clear();selectionActions.hidden=true;copyButton.disabled=false;drawing=true;currentStroke={tool:"select",points:[point]};selectionRect=normalizeRect(point,point);selectionPath=[point];try{canvas.setPointerCapture(event.pointerId);}catch(_){}redraw();return;}if(annotationTool!=="select"&&selectedStrokes.size){selectedStrokes.clear();selectionActions.hidden=true;copyButton.disabled=false;redraw();}if(annotationTool==="eraser"){const rect=canvas.getBoundingClientRect(),radius=eraserSize/Math.max(1,Math.min(rect.width,rect.height));drawing=true;try{canvas.setPointerCapture(event.pointerId);}catch(_){}currentStroke={tool:"eraser",points:[point]};if(eraserMode==="stroke"){const before=strokes.length;strokes=strokes.filter(stroke=>{if(stroke.tool!=="pen")return true;for(let i=0;i<stroke.points.length;i++){if(i===0&&Math.hypot(point[0]-stroke.points[i][0],point[1]-stroke.points[i][1])<radius)return false;if(i>0&&distanceToSegment(point,stroke.points[i-1],stroke.points[i])<radius)return false;}return true;});if(strokes.length!==before){selectedStrokes.clear();selectionActions.hidden=true;pasteMenu.hidden=true;canvas.dataset.dirty="true";canvas.dataset.strokes=JSON.stringify(strokes);redraw();}return;}let changed=false;const eraseAt=p=>{const next=[];for(const stroke of strokes){if(stroke.tool!=="pen"||!stroke.points.length){next.push(stroke);continue;}let segment=[];const flush=()=>{if(segment.length)next.push({...stroke,points:segment});segment=[];};for(const pt of stroke.points){if(Math.hypot(p[0]-pt[0],p[1]-pt[1])<radius){changed=true;flush();}else segment.push(pt);}flush();}if(changed){strokes=next;selectedStrokes.clear();selectionActions.hidden=true;pasteMenu.hidden=true;canvas.dataset.dirty="true";canvas.dataset.strokes=JSON.stringify(strokes);redraw();}};eraseAt(point);return;}currentStroke={tool:"pen",color:penColor,size:penSize,points:[point]};strokes.push(currentStroke);drawing=true;canvas.dataset.dirty="true";canvas.dataset.strokes=JSON.stringify(strokes);drawDot(point);try{canvas.setPointerCapture(event.pointerId);}catch(error){console.warn("Digi could not capture the annotation pointer; continuing with document-level tracking.",error);}});const handleInkMove=event=>{if(!drawing||!currentStroke)return;const events=typeof event.getCoalescedEvents==="function"?event.getCoalescedEvents():[event];for(const sample of events){const point=pointFromEvent(sample);if(currentStroke.tool==="move"){const dx=point[0]-moveStart[0],dy=point[1]-moveStart[1];if(dx||dy){for(const stroke of selectedStrokes){stroke.points=stroke.points.map(p=>[Math.max(0,Math.min(1,p[0]+dx)),Math.max(0,Math.min(1,p[1]+dy)),...p.slice(2)]);}moveStart=point;canvas.dataset.dirty="true";canvas.dataset.strokes=JSON.stringify(strokes);redraw();}continue;}if(currentStroke.tool==="select"){if(selectionMode==="lasso"){selectionPath.push(point);}else{selectionRect=normalizeRect(currentStroke.points[0],point);}redraw();continue;}if(currentStroke.tool==="eraser"){const rect=canvas.getBoundingClientRect(),radius=eraserSize/Math.max(1,Math.min(rect.width,rect.height));let changed=false;if(eraserMode==="stroke"){const next=strokes.filter(stroke=>{if(stroke.tool!=="pen"||!stroke.points.length)return true;for(let i=0;i<stroke.points.length;i++){if(Math.hypot(point[0]-stroke.points[i][0],point[1]-stroke.points[i][1])<radius)return false;if(i>0&&distanceToSegment(point,stroke.points[i-1],stroke.points[i])<radius)return false;}return true;});changed=next.length!==strokes.length;if(changed)strokes=next;}else{const next=[];for(const stroke of strokes){if(stroke.tool!=="pen"||!stroke.points.length){next.push(stroke);continue;}let segment=[];const flush=()=>{if(segment.length)next.push({...stroke,points:segment});segment=[];};for(const pt of stroke.points){if(distanceToSegment(point,pt,pt)<radius){changed=true;flush();}else segment.push(pt);}flush();}if(changed)strokes=next;}if(changed){selectedStrokes.clear();selectionActions.hidden=true;pasteMenu.hidden=true;canvas.dataset.dirty="true";canvas.dataset.strokes=JSON.stringify(strokes);redraw();}currentStroke.points.push(point);continue;}const last=currentStroke.points[currentStroke.points.length-1];if(Math.hypot(point[0]-last[0],point[1]-last[1])<.00025)continue;currentStroke.points.push(point);if(!pendingInkPoints.length)pendingInkPoints.push(last);pendingInkPoints.push(point);}if(currentStroke.tool==="pen")scheduleInkFlush();};canvas.addEventListener("pointermove",handleInkMove);const stop=()=>{if(currentStroke){if(currentStroke.tool==="select"){selectedStrokes.clear();if(selectionMode==="lasso"&&selectionPath.length>2){const inside=(p,poly)=>{let hit=false;for(let i=0,j=poly.length-1;i<poly.length;j=i++){const a=poly[i],b=poly[j];if(((a[1]>p[1])!==(b[1]>p[1]))&&(p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0]))hit=!hit;}return hit;};for(const stroke of strokes){if(stroke.tool==="pen"&&stroke.points.some(p=>inside(p,selectionPath)))selectedStrokes.add(stroke);}}else if(selectionRect&&(selectionRect.right-selectionRect.left>.002||selectionRect.bottom-selectionRect.top>.002)){for(const stroke of strokes){if(stroke.tool==="pen"&&strokeHitsRect(stroke,selectionRect))selectedStrokes.add(stroke);}}selectionRect=null;selectionPath=[];selectionActions.hidden=selectedStrokes.size===0;copyButton.disabled=false;redraw();positionSelectionActions();}if(currentStroke.tool==="move"){canvas.dataset.dirty="true";canvas.dataset.strokes=JSON.stringify(strokes);selectionActions.hidden=selectedStrokes.size===0;positionSelectionActions();}if(currentStroke.tool==="pen"){if(inkFrame){cancelAnimationFrame(inkFrame);inkFrame=0;}flushInk();}drawing=false;currentStroke=null;canvas.dataset.strokes=JSON.stringify(strokes);return;}drawing=false;};selectionActions.querySelectorAll("[data-selection-action]").forEach(button=>button.addEventListener("click",()=>{const action=button.dataset.selectionAction;if(action==="copy"||action==="cut"){sharedStrokeClipboard=[...selectedStrokes].map(stroke=>({...stroke,points:stroke.points.map(p=>[...p])}));if(action==="copy"){button.disabled=true;return;}copyButton.disabled=true;}if(action==="delete"||action==="cut"){strokes=strokes.filter(stroke=>!selectedStrokes.has(stroke));selectedStrokes.clear();selectionActions.hidden=true;canvas.dataset.dirty="true";canvas.dataset.strokes=JSON.stringify(strokes);redraw();}}));canvas.addEventListener("pointerup",stop);canvas.addEventListener("pointercancel",stop);canvas.addEventListener("lostpointercapture",stop);canvas.addEventListener("keydown",event=>{if((event.ctrlKey||event.metaKey)&&event.key.toLowerCase()==="v"&&sharedStrokeClipboard.length){event.preventDefault();pasteStrokes();}});selectionActions.addEventListener("keydown",event=>{if((event.ctrlKey||event.metaKey)&&event.key.toLowerCase()==="v"&&sharedStrokeClipboard.length){event.preventDefault();pasteStrokes();}});});};
 return;
}
panel.innerHTML='<div class="preview-empty"><strong>Preview unavailable</strong><p>This document format is not supported.</p></div>';
});
}
function refresh(){let q=$("search").value.trim();if(!q){$("results").innerHTML='<div class="empty">Type a search term to show files.</div>';$("count").textContent="0 results";$("preview-panel").innerHTML='<div class="preview-empty"><span class="preview-empty-icon">▤</span><strong>Document preview</strong><p>Select a search result to view it here.</p></div>';return}
call("search",[q,$("type").value,$("status").value,$("source").value,"Normal",$("sort").value],raw=>{let rows=parseJson(raw,null,"search results");if(!Array.isArray(rows)){$("results").innerHTML='<div class="empty">Digi could not read search results. Check the startup log.</div>';$("count").textContent="Unavailable";return}rows=rows.filter(r=>String(r.name||"").toLocaleLowerCase().includes(q.toLocaleLowerCase()));$("count").textContent=rows.length+" result(s)";$("results").innerHTML=rows.length?rows.map(r=>{const displayName=String(r.name||"").replace(/\\.[^.\\/]+$/,"");const resultExt=String(r.ext||"").toLowerCase();const resultType=resultExt===".pdf"?"result-type-pdf":([".doc",".docx"].includes(resultExt)?"result-type-word":"");const fileBadge=resultExt===".pdf"?'<span class="result-filetype-icon result-filetype-pdf" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M6 2.75h8l4 4v14.5H6z"/><path d="M14 2.75v4h4M8.5 13h7M8.5 16h7"/><text x="12" y="11" text-anchor="middle" font-size="4.5" stroke="none" fill="currentColor">PDF</text></svg></span>':([".doc",".docx"].includes(resultExt)?'<span class="result-filetype-icon result-filetype-word" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M6 2.75h8l4 4v14.5H6z"/><path d="M14 2.75v4h4"/><path d="m8 12 1.3 5 1.5-3.3 1.5 3.3 1.3-5"/></svg></span>':'');return '<article class="result '+resultType+'" tabindex="0" role="button" aria-label="Preview '+esc(displayName)+'" data-preview="'+esc(r.path)+'" data-name="'+esc(r.name)+'"><div class="result-name">'+fileBadge+esc(displayName)+'</div><div class="result-actions"><button type="button" class="small-button" data-convert="'+esc(r.path)+'" data-kind="'+(resultExt===".pdf"?"word":"pdf")+'" aria-label="Convert to '+(r.ext===".pdf"?"Word":"PDF")+'" title="Convert to '+(r.ext===".pdf"?"Word":"PDF")+'">'+'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 7h11l-3-3M18 7l-3 3M17 17H6l3 3M6 17l3-3"/></svg>'+'</button><button type="button" class="small-button result-icon-button" data-open="'+esc(r.path)+'" aria-label="Open file" title="Open file"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M14 3h7v7M21 3l-9 9"/><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/></svg></button><button type="button" class="small-button result-icon-button" data-folder="'+esc(r.path)+'" aria-label="Open containing folder" title="Open containing folder"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 7.5A2.5 2.5 0 0 1 5.5 5H10l2 2h6.5A2.5 2.5 0 0 1 21 9.5v8a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 17.5z"/><path d="M3.5 10h17"/></svg></button></div></article>'}).join(""):'<div class="empty">No matching files.</div>';
document.querySelectorAll("[data-preview]").forEach(card=>{const select=()=>showPreview(card.dataset.preview,card.dataset.name,card);card.onclick=e=>{if(e.target.closest("button"))return;select()};card.onkeydown=e=>{if((e.key==="Enter"||e.key===" ")&&!e.target.closest("button")){e.preventDefault();select()}};});
document.querySelectorAll("[data-open]").forEach(b=>b.onclick=e=>{e.stopPropagation();openSelectedFile(b.dataset.open)});document.querySelectorAll("[data-folder]").forEach(b=>b.onclick=e=>{e.stopPropagation();call("openFolder",[b.dataset.folder])});document.querySelectorAll("[data-convert]").forEach(b=>b.onclick=e=>{e.stopPropagation();if(b.dataset.kind==="word")confirmPdfToWordConversion(b);else startConversion(b)});});}
function openSearchRepositoryBrowser(initialPath = "") {
  modal("Search repository", '<div class="repo-browser"><div class="repo-browser-path-wrap"><span class="repo-browser-path-prefix">Search Repository /</span><input class="repo-browser-path" id="repo-browser-path" aria-label="Repository folder path" autocomplete="off" spellcheck="false" placeholder="(root)"><span class="repo-browser-path-help">Edit path and press Enter to navigate</span></div><div class="repo-browser-list" id="repo-browser-list"><button type="button" class="repo-browser-back-icon repo-browser-list-back" id="repo-browser-back" aria-label="Go to parent folder" title="Back" hidden><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M15 18l-6-6-6 6M9 12h11"/></svg></button><div class="empty">Loading folders…</div></div></div>');
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
      pathLabel.dataset.isRoot = relativePath ? "false" : "true";
      if (!relativePath && Array.isArray(data.entries)) {
        const visibleRootFolders = data.entries
          .filter(entry => entry.type === "folder" && typeof entry.name === "string")
          .map(entry => entry.name);
        window.digiRepositoryFolderCache = Array.from(new Set([
          ...visibleRootFolders,
          ...(Array.isArray(window.digiRepositoryFolderCache) ? window.digiRepositoryFolderCache : [])
        ]));
        // Immediately update the placeholder when returning to the root.
        // Don't wait for the recursive background scan to finish.
        const pathInput = $("repo-browser-path");
        if (pathInput && pathInput.dataset.isRoot === "true" && pathInput.placeholder === "(root)" && window.digiRepositoryFolderCache.length) {
          pathInput.placeholder = window.digiRepositoryFolderCache[0];
        }
      }
      list.innerHTML = "";
      if (data.parent) {
        const backButton = document.createElement("button");
        backButton.type = "button";
        backButton.className = "repo-browser-back-icon repo-browser-list-back";
        backButton.setAttribute("aria-label", "Go to parent folder");
        backButton.title = "Back";
        backButton.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M15 18l-6-6 6-6M9 12h11"/></svg>';
        backButton.onclick = () => renderRepository(data.parent);
        list.appendChild(backButton);
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
  const rootPathInput = $("repo-browser-path");
  if (rootPathInput) {
    // The cycle is independent from scanning. Keep the current index and the
    // last known list while a background refresh runs.
    let repositoryFolders = Array.isArray(window.digiRepositoryFolderCache)
      ? window.digiRepositoryFolderCache.slice() : [];
    let folderCycleIndex = 0;
    let folderCycleTimer = null;
    let folderRefreshTimer = null;
    let refreshInProgress = false;
    const stopFolderPlaceholderTimers = () => {
      if (folderCycleTimer) clearInterval(folderCycleTimer);
      if (folderRefreshTimer) clearInterval(folderRefreshTimer);
      folderCycleTimer = null;
      folderRefreshTimer = null;
    };
    const rotateFolderPlaceholder = () => {
      const sharedFolderCache = window.digiRepositoryFolderCache;
      if (Array.isArray(sharedFolderCache) && sharedFolderCache.length) {
        repositoryFolders = sharedFolderCache.slice();
      }
      if (!rootPathInput.isConnected) {
        stopFolderPlaceholderTimers();
        return;
      }
      if (rootPathInput.dataset.isRoot !== "true") return;
      if (document.activeElement === rootPathInput && rootPathInput.value.trim()) return;
      if (!repositoryFolders.length) {
        rootPathInput.placeholder = "(root)";
        return;
      }
      rootPathInput.placeholder = repositoryFolders[folderCycleIndex % repositoryFolders.length];
      folderCycleIndex = (folderCycleIndex + 1) % repositoryFolders.length;
    };
    const refreshRepositoryFolderCycle = () => {
      if (!rootPathInput.isConnected) {
        stopFolderPlaceholderTimers();
        return;
      }
      if (refreshInProgress) return;
      refreshInProgress = true;
      call("listSearchRepositoryFolders", [], raw => {
        refreshInProgress = false;
        if (!rootPathInput.isConnected) {
          stopFolderPlaceholderTimers();
          return;
        }
        const result = parseJson(raw, null, "repository folder placeholder scan");
        if (!result || !result.ok || !Array.isArray(result.folders)) {
          // Keep cycling through the folders already visible in the explorer
          // instead of falling back to "(root)" when the background scan fails.
          rotateFolderPlaceholder();
          return;
        }
        const updatedFolders = result.folders
          .filter(path => typeof path === "string" && path.trim())
          .sort((a, b) => a.localeCompare(b, undefined, {sensitivity: "base"}));
        // Include currently visible root folders immediately, even if the
        // recursive scan races with a newly-created folder.
        const rootListing = document.querySelector("#repo-browser-list");
        if (rootPathInput.dataset.isRoot === "true" && rootListing) {
          rootListing.querySelectorAll(".repo-browser-entry").forEach(entry => {
            const name = entry.dataset.name;
            if (name) updatedFolders.push(name);
          });
        }
        const uniqueUpdatedFolders = Array.from(new Set(updatedFolders))
          .sort((a, b) => a.localeCompare(b, undefined, {sensitivity: "base"}));
        // Do not reset the cycle when a scan completes; scanning must not
        // affect the 2-second animation or make it restart from the first item.
        const currentFolder = repositoryFolders.length
          ? repositoryFolders[folderCycleIndex % repositoryFolders.length] : "";
        repositoryFolders = uniqueUpdatedFolders;
        window.digiRepositoryFolderCache = uniqueUpdatedFolders.slice();
        if (currentFolder) {
          const sameIndex = repositoryFolders.indexOf(currentFolder);
          folderCycleIndex = sameIndex >= 0 ? sameIndex : folderCycleIndex % Math.max(repositoryFolders.length, 1);
        } else {
          folderCycleIndex = folderCycleIndex % Math.max(repositoryFolders.length, 1);
        }
      });
    };
    // Start the animation immediately from cached/root-visible folders.
    rotateFolderPlaceholder();
    refreshRepositoryFolderCycle();
    folderCycleTimer = setInterval(rotateFolderPlaceholder, 2000);
    folderRefreshTimer = setInterval(refreshRepositoryFolderCycle, 3000);
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
function showDropReplacePrompt(name, type, onReplace, onCancel) {
  document.querySelectorAll('.repo-drop-replace').forEach(node => node.remove());
  const overlay = document.createElement('div');
  overlay.className = 'repo-drop-replace';
  overlay.innerHTML = '<div class="repo-drop-replace-card" role="alertdialog" aria-modal="true" aria-labelledby="repo-drop-replace-title"><div class="repo-drop-replace-title" id="repo-drop-replace-title">Item already exists</div><p class="repo-drop-replace-message"></p><div class="repo-drop-replace-actions"><button type="button" class="repo-drop-cancel">Cancel</button><button type="button" class="repo-drop-confirm">Replace</button></div></div>';
  overlay.querySelector('.repo-drop-replace-message').textContent = 'A ' + type + ' named "' + name + '" already exists here. Replace it with the dropped ' + type + '?';
  const close = () => overlay.remove();
  overlay.querySelector('.repo-drop-cancel').addEventListener('click', () => { close(); if (onCancel) onCancel(); });
  overlay.querySelector('.repo-drop-confirm').addEventListener('click', () => { close(); if (onReplace) onReplace(); });
  overlay.addEventListener('click', event => { if (event.target === overlay) { close(); if (onCancel) onCancel(); } });
  document.body.appendChild(overlay);
  overlay.querySelector('.repo-drop-cancel').focus();
}
function nativeDropTarget(x, y) {
  const target = document.elementFromPoint(Number(x) || 0, Number(y) || 0);
  return target && target.closest('.repo-browser-list');
}
function clearNativeDropState() {
  document.querySelectorAll('.repo-browser-list.repo-browser-native-drop').forEach(list => {
    list.classList.remove('repo-browser-native-drop');
    const hint = list.querySelector('.repo-browser-native-drop-hint');
    if (hint) hint.remove();
  });
}
window.handleNativeItemsDragLeave = function () { clearNativeDropState(); };
window.handleNativeItemsDragMove = function (serializedPaths, x, y, hasFolder) {
  clearNativeDropState();
  const list = nativeDropTarget(x, y);
  if (!list) return;
  list.classList.add('repo-browser-native-drop');
  const hint = document.createElement('div');
  hint.className = 'repo-browser-native-drop-hint';
  hint.textContent = hasFolder ? 'Move folder(s)' : 'Move file(s)';
  list.appendChild(hint);
};
window.handleNativeItemsDrop = function (serializedPaths, x, y) {
  const list = nativeDropTarget(x, y);
  clearNativeDropState();
  if (!list) return;
  let paths = [];
  try { paths = JSON.parse(serializedPaths || '[]'); } catch (_) {}
  paths = Array.isArray(paths) ? paths.filter(path => typeof path === 'string' && path.trim()) : [];
  const browser = document.querySelector('.repo-browser');
  if (!browser || !paths.length) {
    showRepositoryDropMessage('Nothing to add', 'Drop files or folders directly into the Search Repository folder list.');
    return;
  }
  const pathLabel = browser.querySelector('#repo-browser-path');
  const destination = pathLabel && typeof pathLabel.dataset.currentPath === 'string' ? pathLabel.dataset.currentPath : '';
  list.classList.add('repo-browser-importing');
  const importNext = index => {
    if (index >= paths.length) {
      list.classList.remove('repo-browser-importing');
      openSearchRepositoryBrowser(destination);
      if (typeof refresh === 'function') refresh();
      return;
    }
    const sourcePath = paths[index];
    const retryImport = replaceExisting => {
      call('importDroppedItem', [sourcePath, destination, replaceExisting], raw => {
        const result = parseJson(raw, null, 'dropped item import');
        if (result && result.conflict) {
          const droppedType = result.type === 'folder' ? 'folder' : 'file';
          showDropReplacePrompt(result.name || sourcePath.split(/[\\/]/).pop(), droppedType,
            () => retryImport(true),
            () => {
              if (list) list.classList.remove('repo-browser-importing');
              openSearchRepositoryBrowser(destination);
            });
          return;
        }
        if (!result || !result.ok) {
          list.classList.remove('repo-browser-importing');
          showRepositoryDropMessage('Could not add item', result && result.error ? result.error : 'Digi could not copy this file or folder.');
          return;
        }
        importNext(index + 1);
      });
    };
    retryImport(false);
  };
  importNext(0);
};
const repositoryButton = $("open-search-repository");
if (repositoryButton) repositoryButton.addEventListener("click", openSearchRepositoryBrowser);
function conversionButton(path){return [...document.querySelectorAll("[data-convert]")].find(b=>b.dataset.convert===path);}
function startConversion(button){if(button.disabled)return;button.disabled=true;button.classList.add("conversion-active");button.dataset.original=button.textContent;button.innerHTML='<span class="conversion-label">0%</span><span class="conversion-track"><span class="conversion-fill"></span></span>';call("convert",[button.dataset.convert,button.dataset.kind],ok=>{if(ok===false)finishConversion(button,false,"Conversion could not be started.");});}
function finishConversion(button,success,message){if(!button)return;if(!success){button.disabled=false;button.classList.remove("conversion-active");button.textContent=button.dataset.original||"Convert";if(message)alert("Conversion failed: "+message);return}button.disabled=true;button.classList.remove("conversion-active");button.classList.add("conversion-success");button.innerHTML='<span class="success-check">✓</span> Success';const panel=$("preview-panel");if(panel)panel.innerHTML='<div class="preview-empty"><span class="preview-empty-icon">▤</span><strong>Document preview</strong><p>Conversion completed. Select the renamed file to preview it.</p></div>';setTimeout(()=>{button.classList.add("conversion-fading");setTimeout(()=>{button.classList.remove("conversion-success","conversion-fading");button.disabled=false;button.textContent=button.dataset.original||"Convert";refresh()},350)},3000);}

function confirmPdfToWordConversion(button){
 const overlay=document.createElement("div");
 overlay.className="digi-pdf-word-confirm-overlay";
 overlay.setAttribute("role","presentation");
 overlay.style.cssText="position:fixed;inset:0;z-index:2147483000;display:flex;align-items:center;justify-content:center;padding:16px;background:rgba(0,0,0,.68);backdrop-filter:blur(7px);";
 const dialog=document.createElement("section");
 dialog.setAttribute("role","alertdialog");dialog.setAttribute("aria-modal","true");dialog.setAttribute("aria-labelledby","digi-pdf-word-confirm-title");
 dialog.style.cssText="box-sizing:border-box;width:min(400px,calc(100vw - 32px));height:auto;max-height:calc(100vh - 32px);padding:22px 24px 24px;display:flex;flex-direction:column;align-items:center;gap:16px;background:#171a15;color:#f1f5e8;border:1px solid #3a4132;border-radius:16px;box-shadow:0 20px 60px rgba(0,0,0,.6);font-family:inherit;text-align:center;";
 const title=document.createElement("div");title.id="digi-pdf-word-confirm-title";title.textContent="Are you sure?";title.style.cssText="font-size:18px;font-weight:700;line-height:1.3;";
 const message=document.createElement("p");message.textContent="You won't be able to erase your previous annotations!";message.style.cssText="margin:0;color:#c9cdbf;font-size:13px;line-height:1.5;";
 const actions=document.createElement("div");actions.style.cssText="display:flex;justify-content:center;gap:10px;width:100%;margin-top:4px;";
 const makeButton=(label,bg,border)=>{const b=document.createElement("button");b.type="button";b.textContent=label;b.style.cssText="min-width:104px;padding:10px 20px;border:1px solid "+border+";border-radius:9px;background:"+bg+";color:#fff;font:600 13px inherit;cursor:pointer;pointer-events:auto;";return b;};
 const no=makeButton("No","#237447","#32965d"),yes=makeButton("Yes","#a92b2b","#d34a4a");
 const close=()=>{overlay.remove();};
 no.addEventListener("click",e=>{e.preventDefault();e.stopPropagation();close();});
 yes.addEventListener("click",e=>{e.preventDefault();e.stopPropagation();close();startConversion(button);});
 actions.append(no,yes);dialog.append(title,message,actions);overlay.append(dialog);document.body.append(overlay);no.focus();
}

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

function openTimer(){
  modal("Digi Timer",'<section class="digi-timer"><div class="digi-timer-display" id="digi-timer-display" role="timer" aria-live="off">25:00</div><div class="digi-timer-presets"><button type="button" class="small-button" data-minutes="5">5 min</button><button type="button" class="small-button" data-minutes="15">15 min</button><button type="button" class="small-button" data-minutes="25">25 min</button><button type="button" class="small-button" data-minutes="45">45 min</button></div><div class="digi-timer-custom"><label for="digi-timer-minutes">Minutes</label><input id="digi-timer-minutes" type="number" min="1" max="999" value="25"></div><div class="digi-timer-actions"><button type="button" class="small-button" id="digi-timer-reset">Reset</button><button type="button" class="small-button digi-timer-start" id="digi-timer-start">Start</button></div><p class="digi-timer-status" id="digi-timer-status" role="status">Ready when you are.</p></section>');
  const display=$("digi-timer-display"), minutesInput=$("digi-timer-minutes"), start=$("digi-timer-start"), reset=$("digi-timer-reset"), status=$("digi-timer-status");
  if(!display||!minutesInput||!start||!reset||!status)return;
  let remaining=25*60, deadline=0, interval=null, running=false;
  const format=seconds=>String(Math.floor(seconds/60)).padStart(2,"0")+":"+String(seconds%60).padStart(2,"0");
  const render=()=>{display.textContent=format(remaining);};
  const stop=()=>{if(interval!==null)clearInterval(interval);interval=null;running=false;start.textContent="Start";};
  const tick=()=>{remaining=Math.max(0,Math.ceil((deadline-Date.now())/1000));render();if(remaining===0){stop();status.textContent="Timer complete.";start.disabled=true;try{if("Notification"in window&&Notification.permission==="granted")new Notification("Digi Timer",{body:"Your timer has finished."});}catch(_){}}};
  const setDuration=value=>{stop();start.disabled=false;const mins=Math.min(999,Math.max(1,Math.floor(Number(value)||25)));minutesInput.value=String(mins);remaining=mins*60;render();status.textContent="Ready when you are.";};
  document.querySelectorAll(".digi-timer-presets [data-minutes]").forEach(button=>button.onclick=()=>setDuration(button.dataset.minutes));
  minutesInput.onchange=()=>setDuration(minutesInput.value);
  start.onclick=()=>{if(running){tick();stop();status.textContent="Paused.";return;}if(remaining<=0)setDuration(minutesInput.value);deadline=Date.now()+remaining*1000;running=true;start.textContent="Pause";status.textContent="Timer running.";interval=setInterval(tick,250);};
  reset.onclick=()=>setDuration(minutesInput.value);
  const observer=new MutationObserver(()=>{if($("modal")?.classList.contains("hidden")){stop();observer.disconnect();}});
  observer.observe($("modal"),{attributes:true,attributeFilter:["class"]});
}

function setupCanvas(){
  const c=$("note-canvas");
  if(!c)return;
  notes.canvas=c;
  notes.ctx=c.getContext("2d",{alpha:false,desynchronized:true})||c.getContext("2d");
  const ctx=notes.ctx;
  ctx.fillStyle="#fff";
  ctx.fillRect(0,0,c.width,c.height);
  ctx.lineCap="round";
  ctx.lineJoin="round";
  c.style.touchAction="none";
  c.style.willChange="contents";
  let activePointer=null,rawLast=null,filteredLast=null,strokePoints=[],filterState=null;
  let canvasRect=null,baseWidth=3;
  const pos=e=>{
    if(!canvasRect)canvasRect=c.getBoundingClientRect();
    return{x:(e.clientX-canvasRect.left)*c.width/Math.max(1,canvasRect.width),y:(e.clientY-canvasRect.top)*c.height/Math.max(1,canvasRect.height),pressure:Number.isFinite(e.pressure)&&e.pressure>0?e.pressure:0.5};
  };
  // Constant-velocity Kalman filter: smooths sensor jitter without waiting for a future pointer sample.
  const kalman=(measurement,axis)=>{
    const f=filterState[axis];
    const dt=Math.max(1,Math.min(32,performance.now()-f.time));
    f.time=performance.now();
    f.x+=f.v*dt;
    f.p+=dt*dt*f.vp+2*dt*f.cov+1.5;
    f.cov+=dt*f.vp;
    const noise=2.2;
    const gain=f.p/(f.p+noise);
    const residual=measurement-f.x;
    f.x+=gain*residual;
    f.v+=Math.max(.04,Math.min(.22,gain*.12))*residual/dt;
    f.vp=Math.max(.001,(1-gain)*f.vp+.015);
    f.cov=(1-gain)*f.cov;
    f.p=Math.max(.01,(1-gain)*f.p);
    return f.x;
  };
  const filterPoint=point=>{
    if(!filterState){
      const now=performance.now();
      filterState={
        x:{x:point.x,v:0,p:8,vp:1,cov:0,time:now},
        y:{x:point.y,v:0,p:8,vp:1,cov:0,time:now}
      };
      return {...point};
    }
    return {...point,x:kalman(point.x,"x"),y:kalman(point.y,"y")};
  };
  const midpoint=(a,b)=>({x:(a.x+b.x)/2,y:(a.y+b.y)/2,pressure:(a.pressure+b.pressure)/2});
  const widthFor=point=>{
    const scale=(c.width/Math.max(1,canvasRect.width)+c.height/Math.max(1,canvasRect.height))/2;
    return Math.max(.6,(Number(notes.size)||3)*scale*(.45+(point.pressure||.5)*1.1));
  };
  const setStrokeStyle=point=>{
    const erasing=notes.tool==="eraser";
    ctx.globalCompositeOperation=erasing?"destination-out":"source-over";
    ctx.strokeStyle=notes.color||"#111111";
    ctx.lineWidth=erasing?Math.max(8,widthFor(point)*4):widthFor(point);
  };
  const dot=point=>{
    setStrokeStyle(point);
    ctx.beginPath();
    ctx.arc(point.x,point.y,ctx.lineWidth/2,0,Math.PI*2);
    ctx.fillStyle=notes.color||"#111111";
    ctx.fill();
  };
  const drawSplineSegment=(p0,p1,p2,p3)=>{
    // Uniform cubic B-spline expressed as a cubic Bezier between adjacent spline points.
    const start={x:(p0.x+4*p1.x+p2.x)/6,y:(p0.y+4*p1.y+p2.y)/6};
    const end={x:(p1.x+4*p2.x+p3.x)/6,y:(p1.y+4*p2.y+p3.y)/6};
    const c1={x:(2*p1.x+p2.x)/3,y:(2*p1.y+p2.y)/3};
    const c2={x:(p1.x+2*p2.x)/3,y:(p1.y+2*p2.y)/3};
    const pressure=(p1.pressure+4*p2.pressure+p3.pressure)/6;
    setStrokeStyle({pressure});
    ctx.beginPath();
    ctx.moveTo(start.x,start.y);
    ctx.bezierCurveTo(c1.x,c1.y,c2.x,c2.y,end.x,end.y);
    ctx.stroke();
    return end;
  };
  const drawNewPoint=point=>{
    if(!strokePoints.length){strokePoints.push(point);dot(point);return;}
    strokePoints.push(point);
    const n=strokePoints.length;
    if(n===2){
      setStrokeStyle(point);
      ctx.beginPath();ctx.moveTo(strokePoints[0].x,strokePoints[0].y);
      ctx.lineTo(point.x,point.y);ctx.stroke();
    }else if(n===3){
      const a=strokePoints[0],b=strokePoints[1],d=strokePoints[2],start=midpoint(a,b),end=midpoint(b,d);
      setStrokeStyle(b);ctx.beginPath();ctx.moveTo(start.x,start.y);
      ctx.quadraticCurveTo(b.x,b.y,end.x,end.y);ctx.stroke();
    }else{
      drawSplineSegment(strokePoints[n-4],strokePoints[n-3],strokePoints[n-2],strokePoints[n-1]);
    }
  };
  c.onpointerdown=e=>{
    if(e.button!==undefined&&e.button!==0)return;
    e.preventDefault();
    canvasRect=c.getBoundingClientRect();
    activePointer=e.pointerId;
    rawLast=pos(e);
    filteredLast=filterPoint(rawLast);
    strokePoints=[];
    baseWidth=Number(notes.size)||3;
    ctx.save();
    ctx.lineCap="round";ctx.lineJoin="round";
    drawNewPoint(filteredLast);
    try{c.setPointerCapture(e.pointerId);}catch(_){}
    notes.dirty=true;
  };
  c.onpointermove=e=>{
    if(activePointer!==e.pointerId||!rawLast)return;
    e.preventDefault();
    const events=typeof e.getCoalescedEvents==="function"?e.getCoalescedEvents():[e];
    for(const sample of events){
      const raw=pos(sample);
      if(Math.hypot(raw.x-rawLast.x,raw.y-rawLast.y)<.12)continue;
      rawLast=raw;
      filteredLast=filterPoint(raw);
      drawNewPoint(filteredLast);
    }
    notes.dirty=true;
  };
  const finish=e=>{
    if(activePointer!==null&&e.pointerId!==undefined&&e.pointerId!==activePointer)return;
    if(strokePoints.length>1){
      const lastPoint=strokePoints[strokePoints.length-1];
      const prior=strokePoints.length>2?strokePoints[strokePoints.length-2]:strokePoints[0];
      setStrokeStyle(lastPoint);
      ctx.beginPath();ctx.moveTo(lastPoint.x,lastPoint.y);
      ctx.lineTo(lastPoint.x+(lastPoint.x-prior.x)*.12,lastPoint.y+(lastPoint.y-prior.y)*.12);
      ctx.stroke();
    }
    if(activePointer!==null)ctx.restore();
    activePointer=null;rawLast=null;filteredLast=null;strokePoints=[];filterState=null;canvasRect=null;
  };
  c.onpointerup=finish;
  c.onpointercancel=finish;
  c.onlostpointercapture=finish;
}function loadNotes(){call("notesTree",[],raw=>{let tree=parseJson(raw,null,"notes tree"),el=$("note-tree");if(!el)return;if(!Array.isArray(tree)){el.textContent="Notes could not be loaded.";return}el.innerHTML="";let walk=(items,d)=>items.forEach(x=>{let b=document.createElement("button");b.className="small-button";b.style.display="block";b.style.margin="0 0 5px "+(d*10)+"px";b.textContent=(x.type==="folder"?"▣ ":"▤ ")+x.name;b.onclick=()=>{notes.current=x.path;if(x.type==="page")call("loadNote",[x.path],loadData)};el.appendChild(b);if(x.children)walk(x.children,d+1)});walk(tree,0)});}
function loadData(data){let img=new Image();img.onload=()=>{let c=notes.canvas;c.width=Math.max(1100,img.width);c.height=Math.max(650,img.height);notes.ctx.drawImage(img,0,0);notes.dirty=false};img.src=data;}
function saveNote(){if(notes.current&&notes.canvas)call("saveNote",[notes.current,notes.canvas.toDataURL("image/png")],()=>notes.dirty=false);}
$("window-minimize").onclick=()=>call("minimizeWindow");$("window-maximize").onclick=()=>{document.documentElement.classList.toggle("window-maximized");call("toggleMaximizeWindow");};$("window-close").onclick=()=>call("closeWindow");
const filtersToggle=$("filters-toggle"), filtersOverlay=$("filters-overlay"), filtersClose=$("filters-close");
$("search-window-close").onclick=closeSearchWindow;
$("search-window").addEventListener("click",event=>{if(event.target===$("search-window"))closeSearchWindow();});
document.addEventListener("keydown",event=>{if(event.key==="Escape"&&document.body.classList.contains("search-window-open"))closeSearchWindow();});

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
$("search").oninput=()=>{if(!$("search").value.trim())document.body.classList.remove("filters-open");syncEmptySearchBackButton();scheduleRefreshButton();refresh();};
$("clear").onclick=()=>{$("search").value="";syncEmptySearchBackButton();scheduleRefreshButton();refresh()};

let searchWindowPlaceholders=null;
function syncEmptySearchBackButton(){
  const overlay=$("search-window"),search=$("search"),button=$("search-empty-back");
  if(!overlay||!search||!button)return;
  button.hidden=!document.body.classList.contains("search-window-open")||Boolean(search.value.trim());
}
function ensureEmptySearchBackButton(){
  const overlay=$("search-window");
  if(!overlay||$("search-empty-back"))return;
  const button=document.createElement("button");
  button.id="search-empty-back";
  button.type="button";
  button.className="search-empty-back";
  button.setAttribute("aria-label","Back");
  button.title="Back";
  button.innerHTML='<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>';
  button.hidden=true;
  button.addEventListener("click",closeSearchWindow);
  overlay.appendChild(button);
}
function openSearchWindow(){
  const overlay=$("search-window");
  const content=overlay&&overlay.querySelector(".search-window-content");
  const searchGroup=document.querySelector(".header .search-refresh-group");
  const layout=document.querySelector("body > .layout");
  const filtersToggle=$("filters-toggle");
  const repositoryButton=$("open-search-repository");
  const refreshButton=$("scan");
  const toolbar=$("search-toolbar");
  if(!overlay||!content||!layout||!filtersToggle||!repositoryButton||!refreshButton||!toolbar){
    console.error("Digi Search could not initialise: required Search elements are missing.",{overlay:!!overlay,content:!!content,layout:!!layout,filtersToggle:!!filtersToggle,repositoryButton:!!repositoryButton,refreshButton:!!refreshButton,toolbar:!!toolbar});
    return;
  }
  if(!searchGroup){console.error("Digi Search could not find the search input group.");return;}
  if(!searchWindowPlaceholders){
    const searchMarker=document.createComment("Digi search controls location");
    const layoutMarker=document.createComment("Digi search results location");
    const filtersMarker=document.createComment("Digi filters control location");
    const repositoryMarker=document.createComment("Digi Explorer control location");
    searchGroup.parentNode.insertBefore(searchMarker,searchGroup);
    layout.parentNode.insertBefore(layoutMarker,layout);
    filtersToggle.parentNode.insertBefore(filtersMarker,filtersToggle);
    repositoryButton.parentNode.insertBefore(repositoryMarker,repositoryButton);
    searchWindowPlaceholders={searchMarker,layoutMarker,filtersMarker,repositoryMarker,searchGroup,layout,filtersToggle,repositoryButton};
  }
  toolbar.append(repositoryButton,searchGroup,refreshButton,filtersToggle);
  content.append(toolbar,searchWindowPlaceholders.layout);
  ensureEmptySearchBackButton();
  overlay.hidden=false;
  document.body.classList.add("search-window-open","search-view");
  syncEmptySearchBackButton();
  refresh();
  $("search").focus();
}
function closeSearchWindow(){
  const overlay=$("search-window");
  if(overlay)overlay.hidden=true;
  const backButton=$("search-empty-back");if(backButton)backButton.hidden=true;
  if(searchWindowPlaceholders){
    const {searchMarker,layoutMarker,filtersMarker,repositoryMarker,searchGroup,layout,filtersToggle,repositoryButton}=searchWindowPlaceholders;
    const refreshButton=$("scan");
    if(refreshButton&&searchGroup&&!searchGroup.contains(refreshButton))searchGroup.append(refreshButton);
    if(searchMarker.parentNode)searchMarker.parentNode.insertBefore(searchGroup,searchMarker);
    if(layoutMarker.parentNode)layoutMarker.parentNode.insertBefore(layout,layoutMarker);
    if(filtersMarker.parentNode)filtersMarker.parentNode.insertBefore(filtersToggle,filtersMarker);
    if(repositoryMarker.parentNode)repositoryMarker.parentNode.insertBefore(repositoryButton,repositoryMarker);
    searchMarker.remove();layoutMarker.remove();filtersMarker.remove();repositoryMarker.remove();
    searchWindowPlaceholders=null;
  }
  const search=$("search");
  if(search)search.value="";
  document.body.classList.remove("search-window-open","search-view","filters-open","filters-dialog-open");
  const filtersOverlay=$("filters-overlay");
  if(filtersOverlay)filtersOverlay.hidden=true;
  if(typeof refresh==="function")refresh();
}
["type","status","source","sort"].forEach(id=>$(id).onchange=refresh);$("scan").onclick=()=>call("scan");$("home-search").onclick=openSearchWindow;$("home-notes").onclick=openNotes;$("home-timer").onclick=openTimer;
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
          openDeleteConfirmation(path, name, "file", () => {
            const pathLabel = $('repo-browser-path');
            const currentPath = pathLabel && typeof pathLabel.dataset.currentPath === 'string' ? pathLabel.dataset.currentPath : '';
            openSearchRepositoryBrowser(currentPath);
            if (typeof refresh === 'function') refresh();
          });
        } else {
          openDeleteConfirmation(path, name, "file");
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


// Local updater diagnostic console: reads only the local log file through the backend.
(() => {
  const button = document.getElementById("updater-log-button");
  const overlay = document.getElementById("updater-log-overlay");
  const output = document.getElementById("updater-log-output");
  const state = document.getElementById("updater-log-state");
  if (!button || !overlay || !output || !state) return;

  const refreshLog = () => {
    state.textContent = "READING…";
    output.textContent = "Reading local updater diagnostics…";
    if (!backend || typeof backend.getUpdaterLog !== "function") {
      output.textContent = "[ERROR] Diagnostic bridge is not connected.\n[HINT] Wait for Digi to finish starting, then press Refresh.";
      state.textContent = "BRIDGE OFFLINE";
      return;
    }
    backend.getUpdaterLog(raw => {
      output.textContent = typeof raw === "string" && raw.trim()
        ? raw
        : "[INFO] No updater log content was returned.";
      output.scrollTop = output.scrollHeight;
      state.textContent = "LOCAL / READ ONLY";
    });
  };

  button.addEventListener("click", () => {
    overlay.hidden = false;
    refreshLog();
  });
  document.getElementById("updater-log-close")?.addEventListener("click", () => {
    overlay.hidden = true;
  });
  document.getElementById("updater-log-refresh")?.addEventListener("click", refreshLog);
  overlay.addEventListener("click", event => {
    if (event.target === overlay) overlay.hidden = true;
  });
  document.addEventListener("keydown", event => {
    if (event.key === "Escape" && !overlay.hidden) overlay.hidden = true;
  });
})();


// Persistent light/dark appearance switch.
(() => {
  const button = document.getElementById("theme-toggle");
  if (!button) return;

  const applyTheme = theme => {
    const dark = theme === "dark";
    document.body.classList.toggle("dark-theme", dark);
    document.documentElement.classList.toggle("dark-theme", dark);
    document.documentElement.style.colorScheme = dark ? "dark" : "light";
    button.innerHTML = dark
      ? '<svg class="theme-icon theme-icon-star" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="m12 2.8 2.75 5.58 6.16.9-4.46 4.35 1.05 6.14L12 16.87l-5.5 2.9 1.05-6.14L3.1 9.28l6.16-.9L12 2.8Z"></path></svg>'
      : '<svg class="theme-icon theme-icon-moon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M20.2 15.1A8.6 8.6 0 0 1 8.9 3.8 8.7 8.7 0 1 0 20.2 15.1Z"></path></svg>';
    button.setAttribute("aria-label", dark ? "Light theme" : "Dark theme");
    button.title = dark ? "Switch to light theme" : "Switch to dark theme";
    button.setAttribute("aria-pressed", String(dark));
  };

  let savedTheme = "dark";
  try {
    const stored = localStorage.getItem("digi-theme");
    if (stored === "dark" || stored === "light") savedTheme = stored;
  } catch (error) {
    console.warn("Digi could not read the saved theme preference.", error);
  }

  applyTheme(savedTheme);
  button.addEventListener("click", () => {
    const nextTheme = document.body.classList.contains("dark-theme") ? "light" : "dark";
    applyTheme(nextTheme);
    try {
      localStorage.setItem("digi-theme", nextTheme);
    } catch (error) {
      console.warn("Digi could not save the theme preference.", error);
    }
  });
})();


/* Escape is intentionally not an application shortcut anywhere in Digi. Capture it
   before component handlers so it cannot close dialogs, navigate back, or change views. */
document.addEventListener("keydown", event => {
  if (event.key !== "Escape" && event.key !== "Esc" && event.keyCode !== 27) return;
  event.preventDefault();
  event.stopImmediatePropagation();
}, true);
window.addEventListener("keydown", event => {
  if (event.key !== "Escape" && event.key !== "Esc" && event.keyCode !== 27) return;
  event.preventDefault();
  event.stopImmediatePropagation();
}, true);
