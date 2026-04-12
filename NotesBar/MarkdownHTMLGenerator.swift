import Foundation

/// Utility to generate HTML for different Obsidian file types (Markdown, Canvas, Excalidraw)
struct MarkdownHTMLGenerator {
    
    // MARK: - Canvas
    
    static func generateCanvasHTML(jsonString: String, theme: String) -> String {
        let escapedJSON = jsonString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")

        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            :root {
              --bg: transparent;
              --card-bg: rgba(255,255,255,0.08);
              --card-border: rgba(255,255,255,0.18);
              --card-text: #e0e0e0;
              --card-title: rgba(255,165,0,0.9);
              --edge-color: rgba(255,255,255,0.25);
              --link-color: #58a6ff;
              --group-bg: rgba(255,255,255,0.03);
              --group-border: rgba(255,255,255,0.1);
            }
            @media (prefers-color-scheme: light) {
              :root {
                --card-bg: rgba(0,0,0,0.04);
                --card-border: rgba(0,0,0,0.15);
                --card-text: #1d1d1f;
                --card-title: #cc7700;
                --edge-color: rgba(0,0,0,0.45);
                --link-color: #0066cc;
                --group-bg: rgba(0,0,0,0.02);
                --group-border: rgba(0,0,0,0.08);
              }
            }
            html.theme-light :root {
              --card-bg: rgba(0,0,0,0.04);
              --card-border: rgba(0,0,0,0.15);
              --card-text: #1d1d1f;
              --card-title: #cc7700;
              --edge-color: rgba(0,0,0,0.45);
              --link-color: #0066cc;
            }
            html.theme-dark :root {
              --card-bg: rgba(255,255,255,0.08);
              --card-border: rgba(255,255,255,0.18);
              --card-text: #e0e0e0;
              --card-title: rgba(255,165,0,0.9);
              --edge-color: rgba(255,255,255,0.25);
              --link-color: #58a6ff;
            }
            * { box-sizing: border-box; margin: 0; padding: 0; }
            html, body { width: 100%; height: 100%; overflow: hidden; background: transparent; }
            #canvas-root { width: 100%; height: 100%; position: relative; overflow: hidden; cursor: grab; }
            #canvas-root:active { cursor: grabbing; }
            svg#edges { position: absolute; top: 0; left: 0; width: 100%; height: 100%; pointer-events: none; overflow: visible; }
            .node { position: absolute; background: var(--card-bg); border: 1.5px solid var(--card-border); border-radius: 10px; color: var(--card-text); font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 12px; overflow: hidden; transition: box-shadow 0.2s; user-select: none; }
            .node:hover { box-shadow: 0 0 0 2px rgba(255,150,0,0.4); }
            .node.type-text .node-body { padding: 10px 12px; line-height: 1.5; white-space: pre-wrap; word-break: break-word; overflow: hidden; }
            .node.type-file { border-color: rgba(255,149,0,0.4); }
            .node.type-file .node-header { background: rgba(255,149,0,0.12); padding: 6px 10px; font-size: 11px; font-weight: 600; color: var(--card-title); display: flex; align-items: center; gap: 5px; }
            .node.type-file .node-body { padding: 8px 10px; font-size: 12px; opacity: 0.85; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
            .node.type-link { border-color: rgba(88,166,255,0.4); }
            .node.type-link .node-header { background: rgba(88,166,255,0.12); padding: 6px 10px; font-size: 11px; font-weight: 600; color: var(--link-color); }
            .node.type-link .node-body { padding: 8px 10px; font-size: 11px; word-break: break-all; overflow: hidden; }
            .node.type-group { border-style: dashed; border-color: var(--group-border); background: var(--group-bg); border-radius: 14px; z-index: 0; }
            .node.type-group .group-label { position: absolute; top: 10px; left: 14px; font-size: 11px; font-weight: 700; opacity: 0.5; letter-spacing: 0.05em; text-transform: uppercase; }
            .content-node { z-index: 1; }
            .node-webview { width: 100%; height: 100%; border: none; }
            #canvas-world { animation: fadeIn 0.4s ease-out; }
            @keyframes fadeIn { from { opacity: 0; transform: scale(0.98); } to { opacity: 1; transform: scale(1); } }
          </style>
        </head>
        <body class="theme-\(theme)">
        <div id="canvas-root">
          <div id="canvas-world" style="position:absolute;top:0;left:0;transform-origin:0 0">
            <svg id="edges" style="position:absolute;top:0;left:0;overflow:visible;pointer-events:none;width:1px;height:1px"></svg>
          </div>
        </div>
        <script>
          const RAW = `\(escapedJSON)`;
          let data;
          try { data = JSON.parse(RAW); } catch(e) { document.body.innerHTML = '<p style="color:red;padding:20px">Canvas parse error: ' + e + '</p>'; }
          const root = document.getElementById('canvas-root'), world = document.getElementById('canvas-world'), svgEl = document.getElementById('edges');
          const nodes = data.nodes || [], edges = data.edges || [];
          if (nodes.length === 0) { root.innerHTML = '<p style="color:var(--card-text,#e0e0e0);padding:20px;opacity:0.5;font-family:-apple-system,sans-serif">Empty canvas</p>'; }
          for (const n of nodes) {
            const el = document.createElement('div');
            el.className = 'node type-' + n.type + (n.type !== 'group' ? ' content-node' : '');
            el.style.left = n.x + 'px'; el.style.top = n.y + 'px'; el.style.width = (n.width || 200) + 'px'; el.style.height = (n.height || 100) + 'px';
            if (n.type === 'text') {
              const body = document.createElement('div'); body.className = 'node-body'; body.style.fontSize = '14px'; body.textContent = (n.text || '').substring(0, 1000); el.appendChild(body);
            } else if (n.type === 'file') {
              const hdr = document.createElement('div'); hdr.className = 'node-header'; hdr.textContent = '📄 ' + (n.file || '').split('/').pop();
              const body = document.createElement('div'); body.className = 'node-body'; body.style.fontSize = '12px'; body.textContent = n.file || ''; el.appendChild(hdr); el.appendChild(body);
            } else if (n.type === 'link') {
              const ifr = document.createElement('iframe'); ifr.src = n.url; ifr.className = 'node-webview'; ifr.style.width = '100%'; ifr.style.height = '100%'; ifr.style.border = 'none'; ifr.style.background = 'white'; ifr.setAttribute('sandbox', 'allow-scripts allow-same-origin'); el.appendChild(ifr);
              const overlay = document.createElement('div'); overlay.style.position = 'absolute'; overlay.style.top = '0'; overlay.style.left = '0'; overlay.style.width = '100%'; overlay.style.height = '100%'; overlay.style.zIndex = '1'; el.appendChild(overlay);
            } else if (n.type === 'group') {
              const lbl = document.createElement('div'); lbl.className = 'group-label'; lbl.style.fontSize = '12px'; lbl.textContent = n.label || 'Group'; el.appendChild(lbl);
            }
            world.appendChild(el);
          }
          const nodeMap = {}; for (const n of nodes) nodeMap[n.id] = n;
          function getConnPoint(node, side, otherNode) {
            const x = node.x, y = node.y, w = node.width || 200, h = node.height || 100;
            if (!side) {
              const dx = (otherNode.x + (otherNode.width||200)/2) - (x + w/2), dy = (otherNode.y + (otherNode.height||100)/2) - (y + h/2);
              if (Math.abs(dx) > Math.abs(dy)) { side = dx > 0 ? 'right' : 'left'; } else { side = dy > 0 ? 'bottom' : 'top'; }
            }
            if (side === 'top') return { x: x + w/2, y: y, side: 'top' };
            if (side === 'bottom') return { x: x + w/2, y: y + h, side: 'bottom' };
            if (side === 'left') return { x: x, y: y + h/2, side: 'left' };
            if (side === 'right') return { x: x + w, y: y + h/2, side: 'right' };
            return { x: x + w/2, y: y + h/2, side: 'center' };
          }
          for (const e of edges) {
            const src = nodeMap[e.fromNode], dst = nodeMap[e.toNode]; if (!src || !dst) continue;
            const p1 = getConnPoint(src, e.fromSide, dst), p2 = getConnPoint(dst, e.toSide, src);
            const x1 = p1.x, y1 = p1.y, x2 = p2.x, y2 = p2.y;
            let cp1x = x1, cp1y = y1, cp2x = x2, cp2y = y2;
            const dist = Math.max(Math.abs(x1 - x2) / 2, Math.abs(y1 - y2) / 2, 20);
            if (p1.side === 'left') cp1x -= dist; else if (p1.side === 'right') cp1x += dist; else if (p1.side === 'top') cp1y -= dist; else if (p1.side === 'bottom') cp1y += dist;
            if (p2.side === 'left') cp2x -= dist; else if (p2.side === 'right') cp2x += dist; else if (p2.side === 'top') cp2y -= dist; else if (p2.side === 'bottom') cp2y += dist;
            const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
            path.setAttribute('d', `M ${x1} ${y1} C ${cp1x} ${cp1y}, ${cp2x} ${cp2y}, ${x2} ${y2}`);
            path.setAttribute('stroke', 'var(--edge-color)'); path.setAttribute('stroke-width', '2'); path.setAttribute('fill', 'none');
            const angle = Math.atan2(y2 - cp2y, x2 - cp2x), arrowLen = 10, arrowAngle = 0.4;
            const ax1 = x2 - arrowLen * Math.cos(angle - arrowAngle), ay1 = y2 - arrowLen * Math.sin(angle - arrowAngle);
            const ax2 = x2 - arrowLen * Math.cos(angle + arrowAngle), ay2 = y2 - arrowLen * Math.sin(angle + arrowAngle);
            const arrow = document.createElementNS('http://www.w3.org/2000/svg', 'path');
            arrow.setAttribute('d', `M ${x2} ${y2} L ${ax1} ${ay1} M ${x2} ${y2} L ${ax2} ${ay2}`);
            arrow.setAttribute('stroke', 'var(--edge-color)'); arrow.setAttribute('stroke-width', '2'); arrow.setAttribute('fill', 'none');
            svgEl.appendChild(path); svgEl.appendChild(arrow);
          }
          let minX=Infinity, minY=Infinity, maxX=-Infinity, maxY=-Infinity;
          nodes.forEach(n => {
            minX = Math.min(minX, n.x); minY = Math.min(minY, n.y);
            maxX = Math.max(maxX, n.x + (n.width||200)); maxY = Math.max(maxY, n.y + (n.height||100));
          });
          const PAD = 50;
          const cw = (nodes.length > 0) ? (maxX - minX) + PAD*2 : 100;
          const ch = (nodes.length > 0) ? (maxY - minY) + PAD*2 : 100;
          const vw = root.clientWidth || 450, vh = root.clientHeight || 400;
          const scale = (nodes.length > 0) ? Math.min(vw/cw, vh/ch, 1) : 1;
          const ox = (nodes.length > 0) ? (vw - cw*scale)/2 - (minX-PAD)*scale : 0;
          const oy = (nodes.length > 0) ? (vh - ch*scale)/2 - (minY-PAD)*scale : 0;

          let panX = ox, panY = oy, currentScale = scale;
          function applyTransform() { world.style.transform = `translate(${panX}px, ${panY}px) scale(${currentScale})`; }
          applyTransform();
          let isPanning=false, sx, sy;
          root.addEventListener('mousedown', e => { isPanning=true; sx=e.clientX-panX; sy=e.clientY-panY; root.style.cursor='grabbing'; });
          window.addEventListener('mousemove', e => { if(!isPanning)return; panX=e.clientX-sx; panY=e.clientY-sy; applyTransform(); });
          window.addEventListener('mouseup', () => { isPanning=false; root.style.cursor='grab'; });
          root.addEventListener('wheel', e => {
            e.preventDefault(); const rect = root.getBoundingClientRect(), mouseX = e.clientX - rect.left, mouseY = e.clientY - rect.top, factor = e.deltaY < 0 ? 1.12 : 0.89;
            const newScale = Math.max(0.1, Math.min(5, currentScale * factor));
            panX = mouseX - (mouseX - panX) * (newScale / currentScale); panY = mouseY - (mouseY - panY) * (newScale / currentScale);
            currentScale = newScale; applyTransform();
          }, { passive: false });
        </script>
        </body>
        </html>
        """
    }
    
    // MARK: - Excalidraw
    
    static func generateExcalidrawHTML(jsonString: String, theme: String) -> String {
        let escapedJSON = jsonString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")

        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            * { box-sizing: border-box; margin: 0; padding: 0; }
            html, body { width: 100%; height: 100%; overflow: hidden; background: transparent; }
            #excalidraw-root { width: 100%; height: 100%; position: relative; overflow: hidden; cursor: grab; }
            #excalidraw-root:active { cursor: grabbing; }
            svg#drawing { position: absolute; top: 0; left: 0; overflow: visible; }
            .empty-msg { color: var(--text); font-family: -apple-system, sans-serif; font-size: 13px; opacity: 0.5; padding: 20px; }
            :root { --text: #e0e0e0; --bg: transparent; }
            @media (prefers-color-scheme: light) { :root { --text: #1d1d1f; } }
            html.theme-light :root { --text: #1d1d1f; }
            html.theme-dark :root { --text: #e0e0e0; }
          </style>
        </head>
        <body class="theme-\(theme)">
        <div id="excalidraw-root"></div>
        <script>
          const RAW = `\(escapedJSON)`;
          let data; try { data = JSON.parse(RAW); } catch(e) { document.getElementById('excalidraw-root').innerHTML = '<p class="empty-msg">Excalidraw parse error: ' + e + '</p>'; }
          const elements = (data && data.elements) || [];
          const root = document.getElementById('excalidraw-root');
          if (elements.length === 0) { root.innerHTML = '<p class="empty-msg">Empty drawing</p>'; }
          else {
            let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
            for (const el of elements) { if (el.isDeleted) continue; minX = Math.min(minX, el.x || 0); minY = Math.min(minY, el.y || 0); maxX = Math.max(maxX, (el.x || 0) + (el.width || 0)); maxY = Math.max(maxY, (el.y || 0) + (el.height || 0)); }
            const PAD = 40, vw = root.clientWidth || 450, vh = root.clientHeight || 400, cw = (maxX - minX) + PAD * 2, ch = (maxY - minY) + PAD * 2;
            const scale = Math.min(vw / cw, vh / ch, 1.5), ox = (vw - cw * scale) / 2 - (minX - PAD) * scale, oy = (vh - ch * scale) / 2 - (minY - PAD) * scale;
            const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
            svg.id = 'drawing'; svg.setAttribute('width', vw); svg.setAttribute('height', vh); root.appendChild(svg);
            const isDark = document.body.classList.contains('theme-dark') || window.matchMedia('(prefers-color-scheme: dark)').matches;
            const defaultStroke = isDark ? '#e0e0e0' : '#1d1d1f';
            function toSVGColor(c) { return (!c || c === 'transparent') ? 'none' : c; }
            for (const el of elements) {
              if (el.isDeleted) continue;
              const x = el.x * scale + ox, y = el.y * scale + oy, w = (el.width || 0) * scale, h = (el.height || 0) * scale;
              const stroke = toSVGColor(el.strokeColor) || defaultStroke, fill = el.backgroundColor && el.backgroundColor !== 'transparent' ? toSVGColor(el.backgroundColor) : 'none';
              const sw = (el.strokeWidth || 1) * scale, opacity = (el.opacity != null ? el.opacity : 100) / 100;
              let svgEl = null;
              if (el.type === 'rectangle') { svgEl = document.createElementNS('http://www.w3.org/2000/svg', 'rect'); svgEl.setAttribute('x', x); svgEl.setAttribute('y', y); svgEl.setAttribute('width', w); svgEl.setAttribute('height', h); svgEl.setAttribute('rx', 4 * scale); }
              else if (el.type === 'diamond') { const cx = x + w/2, cy = y + h/2; svgEl = document.createElementNS('http://www.w3.org/2000/svg', 'polygon'); svgEl.setAttribute('points', `${cx},${y} ${x+w},${cy} ${cx},${y+h} ${x},${cy}`); }
              else if (el.type === 'ellipse') { svgEl = document.createElementNS('http://www.w3.org/2000/svg', 'ellipse'); svgEl.setAttribute('cx', x + w/2); svgEl.setAttribute('cy', y + h/2); svgEl.setAttribute('rx', w/2); svgEl.setAttribute('ry', h/2); }
              else if (el.type === 'line' || el.type === 'arrow') {
                if (el.points && el.points.length >= 2) {
                  const pts = el.points.map(p => `${el.x * scale + ox + p[0] * scale},${el.y * scale + oy + p[1] * scale}`).join(' ');
                  svgEl = document.createElementNS('http://www.w3.org/2000/svg', 'polyline'); svgEl.setAttribute('points', pts); svgEl.setAttribute('fill', 'none');
                  if (el.type === 'arrow') { const mid = 'arr-' + Math.random().toString(36).slice(2); const defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs'); defs.innerHTML = `<marker id="${mid}" markerWidth="6" markerHeight="6" refX="5" refY="3" orient="auto"><path d="M0,0 L0,6 L6,3 z" fill="${stroke}"/></marker>`; svg.appendChild(defs); svgEl.setAttribute('marker-end', `url(#${mid})`); }
                }
              } else if (el.type === 'text') {
                svgEl = document.createElementNS('http://www.w3.org/2000/svg', 'text'); svgEl.setAttribute('x', x); svgEl.setAttribute('y', y + (el.fontSize || 16) * scale); svgEl.setAttribute('font-family', '-apple-system, sans-serif'); svgEl.setAttribute('font-size', (el.fontSize || 16) * scale); svgEl.setAttribute('fill', stroke); svgEl.setAttribute('opacity', opacity);
                const lines = (el.text || '').split('\\n'); if (lines.length <= 1) { svgEl.textContent = el.text || ''; } else { lines.forEach((line, i) => { const ts = document.createElementNS('http://www.w3.org/2000/svg', 'tspan'); ts.setAttribute('x', x); ts.setAttribute('dy', i === 0 ? 0 : (el.fontSize || 16) * scale * 1.2); ts.textContent = line; svgEl.appendChild(ts); }); }
                svg.appendChild(svgEl); continue;
              }
              if (svgEl) { svgEl.setAttribute('stroke', stroke); svgEl.setAttribute('fill', fill); svgEl.setAttribute('stroke-width', sw); svgEl.setAttribute('opacity', opacity); svg.appendChild(svgEl); }
            }
            let panX=ox, panY=oy, panning=false, sx=0, sy=0, cs=scale;
            function applyT(){ svg.style.transform=`translate(${panX}px,${panY}px) scale(${cs})`; svg.style.transformOrigin='0 0'; }
            applyT();
            root.addEventListener('mousedown',e=>{panning=true; sx=e.clientX-panX; sy=e.clientY-panY; root.style.cursor='grabbing';});
            window.addEventListener('mousemove',e=>{if(!panning)return; panX=e.clientX-sx; panY=e.clientY-sy; applyT();});
            window.addEventListener('mouseup',()=>{panning=false; root.style.cursor='grab';});
            root.addEventListener('wheel',e=>{
              e.preventDefault(); const rect=root.getBoundingClientRect(), mx=e.clientX-rect.left, my=e.clientY-rect.top, f=e.deltaY<0?1.12:0.89;
              const ns=Math.max(0.1,Math.min(8,cs*f));
              panX=mx-(mx-panX)*(ns/cs); panY=my-(my-panY)*(ns/cs);
              cs=ns; applyT();
            },{passive:false});
          }
        </script>
        </body>
        </html>
        """
    }

    static func generateExcalidrawMDHTML(compressedBase64: String, textElements: String, theme: String) -> String {
        let escapedBase64 = compressedBase64
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        let textLines = textElements.components(separatedBy: "\n").filter { !$0.isEmpty }
        let textLinesJSON = textLines.map { line -> String in
            let escaped = line.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }.joined(separator: ",")

        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            :root { --bg: transparent; --text: #e0e0e0; --accent: #007AFF; --card: rgba(255,255,255,0.04); --border: rgba(255,255,255,0.1); }
            @media (prefers-color-scheme: light) { :root { --text: #1d1d1f; --accent: #007AFF; --card: rgba(0,0,0,0.03); --border: rgba(0,0,0,0.08); } }
            html.theme-light :root { --text: #1d1d1f; --accent: #007AFF; --card: rgba(0,0,0,0.03); --border: rgba(0,0,0,0.08); }
            html.theme-dark :root { --text: #e0e0e0; --accent: #007AFF; --card: rgba(255,255,255,0.04); --border: rgba(255,255,255,0.1); }
            * { box-sizing: border-box; margin: 0; padding: 0; }
            html, body { width: 100%; height: 100%; overflow: hidden; background: transparent; }
            #root { width: 100%; height: 100%; overflow: auto; padding: 16px; font-family: -apple-system, sans-serif; }
            #drawing-view { width: 100%; height: 100%; overflow: hidden; position: relative; cursor: grab; display: none; }
            #drawing-view:active { cursor: grabbing; }
            svg#excali-svg { position: absolute; top: 0; left: 0; overflow: visible; transform-origin: 0 0; }
            #text-view { color: var(--text); }
            .excali-header { display: flex; align-items: center; gap: 8px; margin-bottom: 16px; padding-bottom: 10px; border-bottom: 1px solid var(--border); }
            .excali-icon { font-size: 20px; }
            .excali-title { font-size: 14px; font-weight: 700; color: var(--accent); }
            .excali-status { font-size: 11px; opacity: 0.5; margin-left: auto; }
            .text-grid { display: flex; flex-direction: column; gap: 6px; }
            .text-card { background: var(--card); border: 1px solid var(--border); border-radius: 8px; padding: 8px 12px; font-size: 13px; color: var(--text); line-height: 1.4; white-space: pre-wrap; word-break: break-word; }
            .btn-visual { margin-top: 12px; padding: 6px 14px; border-radius: 6px; background: var(--accent); color: #fff; border: none; font-size: 12px; font-weight: 600; cursor: pointer; opacity: 0.9; }
            .btn-visual:hover { opacity: 1; }
            .empty { font-size: 13px; opacity: 0.4; padding: 20px; text-align: center; }
          </style>
        </head>
        <body class="theme-\(theme)">
        <div id="root">
          <div id="text-view">
            <div class="excali-header">
              <span class="excali-icon">✏️</span>
              <span class="excali-title">Excalidraw</span>
              <span class="excali-status" id="status-lbl">Loading...</span>
            </div>
            <div class="text-grid" id="text-grid"></div>
          </div>
          <div id="drawing-view"><svg id="excali-svg"></svg></div>
        </div>
        <script>
        var LZString=function(){var f=String.fromCharCode,keyStrBase64="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=",baseReverseDic={};function getBaseValue(a,c){if(!baseReverseDic[a]){baseReverseDic[a]={};for(var i=0;i<a.length;i++)baseReverseDic[a][a[i]]=i}return baseReverseDic[a][c]}var LZString={decompressFromBase64:function(i){if(i==null)return"";if(i=="")return null;return LZString._decompress(i.length,32,function(idx){return getBaseValue(keyStrBase64,i[idx])})},_decompress:function(l,rv,gv){var d=[],ei=4,ds=4,nb=3,entry="",r=[],w,bits,resb,mp,p,c,data={val:gv(0),position:rv,index:1};for(let i=0;i<3;i++)d[i]=i;bits=0;mp=Math.pow(2,2);p=1;while(p!=mp){resb=data.val&data.position;data.position>>=1;if(data.position==0){data.position=rv;data.val=gv(data.index++)}bits|=(resb>0?1:0)*p;p<<=1}switch(c=bits){case 0:bits=0;mp=Math.pow(2,8);p=1;while(p!=mp){resb=data.val&data.position;data.position>>=1;if(data.position==0){data.position=rv;data.val=gv(data.index++)}bits|=(resb>0?1:0)*p;p<<=1}c=f(bits);break;case 1:bits=0;mp=Math.pow(2,16);p=1;while(p!=mp){resb=data.val&data.position;data.position>>=1;if(data.position==0){data.position=rv;data.val=gv(data.index++)}bits|=(resb>0?1:0)*p;p<<=1}c=f(bits);break;case 2:return""}w=c;d[3]=c;r.push(c);while(true){if(data.index>l)return"";bits=0;mp=Math.pow(2,nb);p=1;while(p!=mp){resb=data.val&data.position;data.position>>=1;if(data.position==0){data.position=rv;data.val=gv(data.index++)}bits|=(resb>0?1:0)*p;p<<=1}switch(c=bits){case 0:bits=0;mp=Math.pow(2,8);p=1;while(p!=mp){resb=data.val&data.position;data.position>>=1;if(data.position==0){data.position=rv;data.val=gv(data.index++)}bits|=(resb>0?1:0)*p;p<<=1}d[ds++]=f(bits);c=ds-1;ei--;break;case 1:bits=0;mp=Math.pow(2,16);p=1;while(p!=mp){resb=data.val&data.position;data.position>>=1;if(data.position==0){data.position=rv;data.val=gv(data.index++)}bits|=(resb>0?1:0)*p;p<<=1}d[ds++]=f(bits);c=ds-1;ei--;break;case 2:return r.join("")}if(ei==0){ei=Math.pow(2,nb);nb++}if(d[c]){entry=d[c]}else{if(c===ds){entry=w+w.charAt(0)}else return null}r.push(entry);d[ds++]=w+entry.charAt(0);ei--;w=entry;if(ei==0){ei=Math.pow(2,nb);nb++}}}};return LZString}();
        const COMPRESSED = `\(escapedBase64)`, TEXT_LINES = [\(textLinesJSON)];
        const grid = document.getElementById('text-grid'), lbl = document.getElementById('status-lbl');
        if (TEXT_LINES.length === 0) { grid.innerHTML = '<p class="empty">No text elements</p>'; }
        else { TEXT_LINES.forEach(line => { const card = document.createElement('div'); card.className = 'text-card'; card.textContent = line; grid.appendChild(card); }); }
        if (COMPRESSED) {
          try {
            const json = LZString.decompressFromBase64(COMPRESSED);
            if (json) {
              const data = JSON.parse(json), elements = data.elements || [];
              if (elements.length > 0) { renderVisual(elements); lbl.textContent = elements.length + ' elements'; }
            }
          } catch(e) {}
        }
        function renderVisual(elements) {
          const btn = document.createElement('button'); btn.className = 'btn-visual'; btn.textContent = '✏️ Show Drawing';
          let showingVisual = false;
          const textView = document.getElementById('text-view'), drawView = document.getElementById('drawing-view'), svg = document.getElementById('excali-svg');
          let minX=Infinity,minY=Infinity,maxX=-Infinity,maxY=-Infinity;
          for(const el of elements){ if(el.isDeleted)continue; minX=Math.min(minX,el.x||0);minY=Math.min(minY,el.y||0); maxX=Math.max(maxX,(el.x||0)+(el.width||0)); maxY=Math.max(maxY,(el.y||0)+(el.height||0)); }
          const PAD=40,vw=document.getElementById('root').clientWidth||450,vh=document.getElementById('root').clientHeight||400, cw=(maxX-minX)+PAD*2,ch=(maxY-minY)+PAD*2, sc=Math.min(vw/cw,vh/ch,1.5), ox=(vw-cw*sc)/2-(minX-PAD)*sc, oy=(vh-ch*sc)/2-(minY-PAD)*sc;
          const isDark = document.body.classList.contains('theme-dark') || window.matchMedia('(prefers-color-scheme: dark)').matches;
          const defStroke=isDark?'#e0e0e0':'#1d1d1f';
          function toC(c){return(!c||c==='transparent')?'none':c}
          for(const el of elements){
            if(el.isDeleted)continue;
            const x=el.x*sc+ox,y=el.y*sc+oy,w=(el.width||0)*sc,h=(el.height||0)*sc, stroke=toC(el.strokeColor)||defStroke, fill=el.backgroundColor&&el.backgroundColor!=='transparent'?toC(el.backgroundColor):'none', sw=(el.strokeWidth||1)*sc, opacity=(el.opacity!=null?el.opacity:100)/100;
            let se=null;
            if(el.type==='rectangle'){ se=document.createElementNS('http://www.w3.org/2000/svg','rect'); se.setAttribute('x',x);se.setAttribute('y',y);se.setAttribute('width',w);se.setAttribute('height',h);se.setAttribute('rx',4*sc); }
            else if(el.type==='diamond'){ const cx=x+w/2,cy=y+h/2; se=document.createElementNS('http://www.w3.org/2000/svg','polygon'); se.setAttribute('points',`${cx},${y} ${x+w},${cy} ${cx},${y+h} ${x},${cy}`); }
            else if(el.type==='ellipse'){ se=document.createElementNS('http://www.w3.org/2000/svg','ellipse'); se.setAttribute('cx',x+w/2);se.setAttribute('cy',y+h/2);se.setAttribute('rx',w/2);se.setAttribute('ry',h/2); }
            else if(el.type==='line'||el.type==='arrow'){
              if(el.points&&el.points.length>=2){
                const pts=el.points.map(p=>`${el.x*sc+ox+p[0]*sc},${el.y*sc+oy+p[1]*sc}`).join(' ');
                se=document.createElementNS('http://www.w3.org/2000/svg','polyline'); se.setAttribute('points',pts);se.setAttribute('fill','none');
                if(el.type==='arrow'){ const mid=`arr${Math.random().toString(36).slice(2)}`; const defs=document.createElementNS('http://www.w3.org/2000/svg','defs'); defs.innerHTML=`<marker id="${mid}" markerWidth="6" markerHeight="6" refX="5" refY="3" orient="auto"><path d="M0,0 L0,6 L6,3 z" fill="${stroke}"/></marker>`; svg.appendChild(defs); se.setAttribute('marker-end',`url(#${mid})`); }
              }
            } else if(el.type==='text'){
              se=document.createElementNS('http://www.w3.org/2000/svg','text'); se.setAttribute('x',x);se.setAttribute('y',y+(el.fontSize||16)*sc); se.setAttribute('font-family','sans-serif'); se.setAttribute('font-size',(el.fontSize||16)*sc); se.setAttribute('fill',stroke);se.setAttribute('opacity',opacity);
              const lines=(el.text||'').split('\\n'); if(lines.length<=1){se.textContent=el.text||'';} else{lines.forEach((line,i)=>{const ts=document.createElementNS('http://www.w3.org/2000/svg','tspan');ts.setAttribute('x',x);ts.setAttribute('dy',i===0?0:(el.fontSize||16)*sc*1.2);ts.textContent=line;se.appendChild(ts);});}
              svg.appendChild(se);continue;
            }
            if(se){se.setAttribute('stroke',stroke);se.setAttribute('fill',fill);se.setAttribute('stroke-width',sw);se.setAttribute('opacity',opacity);svg.appendChild(se);}
          }
          let panX=ox,panY=oy,panning=false,sx=0,sy=0,cs=sc;
          function applyT(){svg.style.transform=`translate(${panX}px,${panY}px) scale(${cs})`;svg.style.transformOrigin='0 0';}
          applyT();
          drawView.addEventListener('mousedown',e=>{panning=true;sx=e.clientX-panX;sy=e.clientY-panY;drawView.style.cursor='grabbing';});
          window.addEventListener('mousemove',e=>{if(!panning)return;panX=e.clientX-sx;panY=e.clientY-sy;applyT();});
          window.addEventListener('mouseup',()=>{panning=false;drawView.style.cursor='grab';});
          drawView.addEventListener('wheel',e=>{
            e.preventDefault(); const rect=drawView.getBoundingClientRect(), mx=e.clientX-rect.left, my=e.clientY-rect.top, f=e.deltaY<0?1.12:0.89;
            const ns=Math.max(0.1,Math.min(8,cs*f));
            panX=mx-(mx-panX)*(ns/cs); panY=my-(my-panY)*(ns/cs);
            cs=ns; applyT();
          },{passive:false});
          btn.addEventListener('click', () => {
            showingVisual = !showingVisual;
            if (showingVisual) { textView.style.display = 'none'; drawView.style.display = 'block'; btn.textContent = '📋 Show Text'; }
            else { textView.style.display = 'block'; drawView.style.display = 'none'; btn.textContent = '✏️ Show Drawing'; }
          });
          textView.appendChild(btn);
        }
        </script>
        </body>
        </html>
        """
    }
}
