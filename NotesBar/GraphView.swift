import SwiftUI
import WebKit

struct GraphView: View {
    @ObservedObject var viewModel: GraphViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Vault Graph")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if viewModel.isScanning {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 8)
                }
                
                Button(action: { viewModel.centerView() }) {
                    Image(systemName: "scope")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Center View")
                .padding(.trailing, 4)

                Button(action: { viewModel.showSettings.toggle() }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(viewModel.showSettings ? .accentColor : .primary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Graph Settings")
                .padding(.trailing, 4)

                Button(action: { viewModel.scanVault() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Refresh Graph")
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .padding(4)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .opacity(0.1)
                .padding(.horizontal)
            
            // Graph Area
            ZStack(alignment: .topTrailing) {
                // Background Darkness Overlay (Behind Graph)
                Color.black.opacity(viewModel.settings.backgroundDarkness)
                    .allowsHitTesting(false)

                GraphWebView(
                    json: viewModel.getGraphDataJSON(),
                    vaultPath: viewModel.vaultPath ?? "",
                    settings: viewModel.settings,
                    centerTrigger: viewModel.centerTrigger
                )
                
                if viewModel.showSettings {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Graph Settings")
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                            Button(action: { viewModel.showSettings = false }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.bottom, 4)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                SettingSlider(title: "Node Size", value: $viewModel.settings.nodeSize, range: 1...15)
                                SettingSlider(title: "Link Distance", value: $viewModel.settings.linkDistance, range: 10...300)
                                SettingSlider(title: "Repulsion", value: $viewModel.settings.repulsion, range: -1000...(-50))
                                SettingSlider(title: "Link Thickness", value: $viewModel.settings.linkThickness, range: 0.5...5)
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Node Color")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                    HStack(spacing: 12) {
                                        ForEach(GraphViewModel.presetColors, id: \.self) { colorHex in
                                            Circle()
                                                .fill(Color(hex: colorHex))
                                                .frame(width: 18, height: 18)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: 2)
                                                        .padding(-3)
                                                        .opacity(viewModel.settings.nodeColor == colorHex ? 1 : 0)
                                                )
                                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                                .onTapGesture {
                                                    withAnimation(.spring(response: 0.3)) {
                                                        viewModel.settings.nodeColor = colorHex
                                                    }
                                                }
                                        }
                                    }
                                    .padding(.leading, 4)
                                }
                                
                                SettingSlider(title: "Darkness", value: $viewModel.settings.backgroundDarkness, range: 0...0.9)
                            }
                        }
                        
                        Divider()
                            .opacity(0.1)
                        
                        Button(action: { viewModel.settings = GraphSettings() }) {
                            Text("Reset Defaults")
                                .font(.system(size: 12, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .frame(width: 220)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                    .padding(16)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                }
            }
        }
        .background(.ultraThinMaterial)
        .frame(width: 800, height: 600)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showSettings)
    }
}

struct SettingSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(value))")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.accentColor)
            }
            Slider(value: $value, in: range)
                .controlSize(.small)
        }
    }
}

struct GraphWebView: NSViewRepresentable {
    let json: String
    let vaultPath: String
    let settings: GraphSettings
    let centerTrigger: Int
    
    func makeCoordinator() -> Coordinator {
        Coordinator(vaultPath: vaultPath)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "openNote")
        
        // Pass initial settings via script if needed, or wait for updateNSView
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        
        let html = createGraphHTML()
        webView.loadHTMLString(html, baseURL: nil)
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        // Update data if changed
        if context.coordinator.lastJSON != json {
            context.coordinator.lastJSON = json
            let script = "if (window.updateData) { window.updateData(\(json)); }"
            webView.evaluateJavaScript(script)
        }
        
        // Update settings if changed
        if context.coordinator.lastSettings?.nodeSize != settings.nodeSize ||
           context.coordinator.lastSettings?.linkDistance != settings.linkDistance ||
           context.coordinator.lastSettings?.repulsion != settings.repulsion ||
           context.coordinator.lastSettings?.linkThickness != settings.linkThickness ||
           context.coordinator.lastSettings?.nodeColor != settings.nodeColor {
            
            context.coordinator.lastSettings = settings
            if let settingsJSON = try? String(data: JSONEncoder().encode(settings), encoding: .utf8) {
                let script = "if (window.updateSettings) { window.updateSettings(\(settingsJSON)); }"
                webView.evaluateJavaScript(script)
            }
        }
        
        // Handle center trigger
        if context.coordinator.lastCenterTrigger != centerTrigger {
            context.coordinator.lastCenterTrigger = centerTrigger
            let script = "window.centerView();"
            webView.evaluateJavaScript(script)
        }
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        let vaultPath: String
        var lastJSON: String = ""
        var lastSettings: GraphSettings?
        var lastCenterTrigger: Int = 0
        
        init(vaultPath: String) {
            self.vaultPath = vaultPath
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "openNote", let relativePath = message.body as? String {
                let absolutePath = (vaultPath as NSString).appendingPathComponent(relativePath)
                // Open the note in Obsidian using the absolute path
                if let url = URL(string: "obsidian://open?path=\(absolutePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    private func createGraphHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
          <script src="\(JSAssets.forceGraphScript)"></script>
          <style>
            body { 
                margin: 0; 
                background-color: transparent !important;
                overflow: hidden; 
                user-select: none;
                -webkit-user-select: none;
            }
            :root {
                --bg-color: #ffffff;
                --text-color: #1d1d1f;
            }
            @media (prefers-color-scheme: dark) {
                :root {
                    --bg-color: #1a1a1a;
                    --text-color: #e0e0e0;
                }
            }
            #graph { width: 100vw; height: 100vh; cursor: grab; }
            #graph:active { cursor: grabbing; }
          </style>
        </head>
        <body>
          <div id="graph"></div>
          <script>
            let data = \(json);
            let settings = \( (try? String(data: JSONEncoder().encode(settings), encoding: .utf8)) ?? "{}" );
            const isDarkMode = window.matchMedia('(prefers-color-scheme: dark)').matches;
            
            let hoverNode = null;
            
            const Graph = ForceGraph()
              (document.getElementById('graph'))
                .graphData(data)
                .nodeId('id')
                .nodeLabel(null) 
                .linkColor(() => isDarkMode ? 'rgba(255, 255, 255, 0.2)' : 'rgba(0, 0, 0, 0.1)')
                .linkWidth(() => settings.linkThickness || 1.0)
                .onNodeHover(node => {
                  hoverNode = node;
                  if (!window.isDragging) {
                    document.getElementById('graph').style.cursor = node ? 'pointer' : 'grab';
                  }
                })
                .onNodeDrag(() => {
                  window.isDragging = true;
                  hoverNode = null;
                  document.getElementById('graph').style.cursor = 'grabbing';
                })
                .onNodeDragEnd(() => {
                  window.isDragging = false;
                  document.getElementById('graph').style.cursor = 'grab';
                })
                .nodeCanvasObject((node, ctx, globalScale) => {
                  const label = node.name;
                  const fontSize = 12/globalScale;
                  const r = (settings.nodeSize || 4.0);
                  
                  const nodeColor = settings.nodeColor || "#007AFF";
                  
                  // 1. Draw node circle
                  ctx.beginPath();
                  ctx.arc(node.x, node.y, r, 0, 2 * Math.PI, false);
                  
                  let nodeColor = settings.nodeColor || "#007AFF";
                  if (node.group === 2) nodeColor = "#FF9500"; // Canvas
                  else if (node.group === 3) nodeColor = "#AF52DE"; // Excalidraw
                  
                  if (node === hoverNode) {
                    ctx.shadowColor = nodeColor;
                    ctx.shadowBlur = 15 / globalScale;
                    ctx.fillStyle = nodeColor;
                  } else {
                    ctx.shadowBlur = 0;
                    ctx.fillStyle = nodeColor;
                  }
                  
                  ctx.fill();
                  ctx.shadowBlur = 0;

                  // 2. Draw label if hovered (and not dragging)
                  if (node === hoverNode && !window.isDragging) {
                    ctx.font = `${fontSize}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`;
                    const textWidth = ctx.measureText(label).width;
                    const padding = 6 / globalScale;
                    const bckgW = textWidth + padding * 2;
                    const bckgH = fontSize + padding;
                    
                    const x = node.x - bckgW / 2;
                    const y = node.y - bckgH - r - 4; 
                    
                    ctx.fillStyle = isDarkMode ? 'rgba(20, 20, 20, 0.95)' : 'rgba(255, 255, 255, 0.95)';
                    ctx.strokeStyle = isDarkMode ? 'rgba(255, 255, 255, 0.2)' : 'rgba(0, 0, 0, 0.1)';
                    ctx.lineWidth = 1 / globalScale;
                    
                    const radius = 4 / globalScale;
                    ctx.beginPath();
                    ctx.moveTo(x + radius, y);
                    ctx.lineTo(x + bckgW - radius, y);
                    ctx.quadraticCurveTo(x + bckgW, y, x + bckgW, y + radius);
                    ctx.lineTo(x + bckgW, y + bckgH - radius);
                    ctx.quadraticCurveTo(x + bckgW, y + bckgH, x + bckgW - radius, y + bckgH);
                    ctx.lineTo(x + radius, y + bckgH);
                    ctx.quadraticCurveTo(x, y + bckgH, x, y + bckgH - radius);
                    ctx.lineTo(x, y + radius);
                    ctx.quadraticCurveTo(x, y, x + radius, y);
                    ctx.closePath();
                    ctx.fill();
                    ctx.stroke();
                    
                    ctx.textAlign = 'center';
                    ctx.textBaseline = 'middle';
                    ctx.fillStyle = isDarkMode ? '#ffffff' : '#000000';
                    ctx.fillText(label, node.x, y + bckgH / 2);
                  }
                })
                .onNodeClick(node => {
                  try {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.openNote) {
                      window.webkit.messageHandlers.openNote.postMessage(node.id);
                    }
                  } catch (e) {
                      console.error("Failed to post message", e);
                  }
                });

            const applyForces = () => {
                Graph.d3Force('charge').strength(settings.repulsion || -150);
                Graph.d3Force('link').distance(settings.linkDistance || 30);
            };

            applyForces();
            Graph.onEngineStop(() => Graph.zoomToFit(800, 100));

            window.updateData = (newData) => {
                Graph.graphData(newData);
                applyForces();
                setTimeout(() => Graph.zoomToFit(800, 120), 100);
            };

            window.updateSettings = (newSettings) => {
                settings = newSettings;
                applyForces();
                Graph.linkWidth(() => settings.linkThickness || 1.0);
                // Refresh canvas to apply nodeSize change
                Graph.nodeCanvasObject(Graph.nodeCanvasObject()); 
            };

            window.centerView = () => {
                Graph.zoomToFit(1000, 150);
            };
          </script>
        </body>
        </html>
        """
    }
}
