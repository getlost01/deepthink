import SwiftUI
import WebKit

struct ChatMarkdownView: View {
    let markdown: String
    @State private var contentHeight: CGFloat = 44

    var body: some View {
        ChatMarkdownWebView(markdown: markdown, contentHeight: $contentHeight)
            .frame(height: contentHeight)
    }
}

private struct ChatMarkdownWebView: NSViewRepresentable {
    let markdown: String
    @Binding var contentHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "copyCode")
        config.userContentController.add(context.coordinator, name: "contentHeight")

        let webView = ScrollPassthroughWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.lastMarkdown = markdown
        loadContent(webView: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastMarkdown != markdown {
            context.coordinator.lastMarkdown = markdown
            loadContent(webView: webView)
        }
    }

    private func loadContent(webView: WKWebView) {
        let escaped = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
            @media (prefers-color-scheme: dark) {
                :root { --text: #e0e0e0; --text2: #888; --bg-code: rgba(255,255,255,0.04); --border: rgba(255,255,255,0.08); --accent: #4dacf7; --bg-hover: rgba(255,255,255,0.04); --bg-inline: rgba(255,255,255,0.07); }
            }
            @media (prefers-color-scheme: light) {
                :root { --text: #1d1d1f; --text2: #888; --bg-code: rgba(0,0,0,0.03); --border: rgba(0,0,0,0.08); --accent: #1a8ad4; --bg-hover: rgba(0,0,0,0.03); --bg-inline: rgba(0,0,0,0.05); }
            }
            * { box-sizing: border-box; margin: 0; padding: 0; }
            html, body { overflow: hidden; pointer-events: none; }
            a, button, .copy-btn { pointer-events: auto; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
                font-size: 13px;
                line-height: 1.65;
                color: var(--text);
                background: transparent;
                -webkit-font-smoothing: antialiased;
                -webkit-user-select: text;
            }
            h1 { font-size: 17px; font-weight: 700; margin: 16px 0 8px; letter-spacing: -0.3px; }
            h1:first-child { margin-top: 0; }
            h2 { font-size: 15px; font-weight: 600; margin: 14px 0 6px; letter-spacing: -0.2px; }
            h3 { font-size: 14px; font-weight: 600; margin: 12px 0 5px; }
            h4, h5, h6 { font-size: 13px; font-weight: 600; margin: 10px 0 4px; }
            p { margin: 6px 0; }
            a { color: var(--accent); text-decoration: none; border-bottom: 1px solid transparent; transition: border-color 0.15s; }
            a:hover { border-bottom-color: var(--accent); }
            strong { font-weight: 600; }
            em { font-style: italic; }

            code {
                font-family: 'SF Mono', Menlo, monospace;
                font-size: 11.5px;
                background: var(--bg-inline);
                padding: 1px 5px;
                border-radius: 4px;
            }

            .code-block-wrapper {
                position: relative;
                margin: 10px 0;
                border-radius: 10px;
                background: var(--bg-code);
                border: 1px solid var(--border);
                overflow: hidden;
            }
            .code-block-header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                padding: 6px 12px;
                font-size: 10px;
                color: var(--text2);
                border-bottom: 1px solid var(--border);
                font-family: 'SF Mono', Menlo, monospace;
                background: var(--bg-hover);
            }
            .code-lang { font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; font-size: 9px; }
            .copy-btn {
                background: none;
                border: 1px solid var(--border);
                color: var(--text2);
                cursor: pointer;
                font-size: 10px;
                font-family: -apple-system, sans-serif;
                padding: 3px 8px;
                border-radius: 5px;
                transition: all 0.15s;
            }
            .copy-btn:hover { background: var(--bg-code); color: var(--text); border-color: var(--text2); }
            .copy-btn.copied { color: #34c759; border-color: #34c759; }

            pre {
                margin: 0;
                padding: 12px 14px;
                overflow-x: auto;
            }
            pre code {
                background: none;
                padding: 0;
                font-size: 11.5px;
                line-height: 1.55;
            }

            blockquote {
                border-left: 3px solid var(--accent);
                margin: 8px 0;
                padding: 4px 14px;
                color: var(--text2);
                background: var(--bg-code);
                border-radius: 0 6px 6px 0;
            }

            .callout { margin: 10px 0; padding: 10px 14px; border-radius: 8px; border: 1px solid var(--border); display: flex; gap: 10px; align-items: flex-start; }
            .callout-icon { font-size: 15px; flex-shrink: 0; margin-top: 1px; }
            .callout-content { flex: 1; min-width: 0; }
            .callout-content p:first-child { margin-top: 0; }
            .callout-tip { background: rgba(52, 199, 89, 0.08); border-color: rgba(52, 199, 89, 0.2); }
            .callout-warning { background: rgba(255, 149, 0, 0.08); border-color: rgba(255, 149, 0, 0.2); }
            .callout-note { background: var(--bg-code); border-color: var(--border); }
            .callout-important { background: rgba(255, 59, 48, 0.08); border-color: rgba(255, 59, 48, 0.2); }

            table { border-collapse: collapse; width: 100%; margin: 10px 0; font-size: 12px; border-radius: 8px; overflow: hidden; border: 1px solid var(--border); }
            th, td { border: 1px solid var(--border); padding: 7px 12px; text-align: left; }
            th { font-weight: 600; background: var(--bg-code); font-size: 11px; text-transform: uppercase; letter-spacing: 0.3px; color: var(--text2); }
            tr:hover td { background: var(--bg-hover); }

            ul, ol { padding-left: 22px; margin: 6px 0; }
            li { margin: 3px 0; }
            li > p { margin: 1px 0; }
            li::marker { color: var(--text2); }

            ul.task-list { list-style: none; padding-left: 0; }
            .task-list-item { display: flex; align-items: flex-start; gap: 8px; padding: 4px 0; }
            .task-checkbox { width: 16px; height: 16px; border-radius: 4px; border: 1.5px solid var(--border); background: transparent; flex-shrink: 0; margin-top: 2px; display: flex; align-items: center; justify-content: center; cursor: default; }
            .task-checkbox.checked { background: var(--accent); border-color: var(--accent); }
            .task-checkbox.checked::after { content: '✓'; color: white; font-size: 10px; font-weight: 700; }
            .task-list-item.done .task-text { text-decoration: line-through; color: var(--text2); }

            hr { border: none; border-top: 1px solid var(--border); margin: 14px 0; }
            img { max-width: 100%; border-radius: 8px; margin: 6px 0; }
        </style>
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css" media="(prefers-color-scheme: dark)">
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css" media="(prefers-color-scheme: light)">
        <script src="https://cdnjs.cloudflare.com/ajax/libs/marked/12.0.1/marked.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
        </head>
        <body>
        <div id="content"></div>
        <script>
            const renderer = new marked.Renderer();
            renderer.code = function(code, lang) {
                let src = typeof code === 'object' ? code.text : code;
                let language = typeof code === 'object' ? code.lang : lang;
                language = language || '';
                let highlighted;
                try {
                    highlighted = language && hljs.getLanguage(language)
                        ? hljs.highlight(src, { language }).value
                        : hljs.highlightAuto(src).value;
                } catch(e) {
                    highlighted = src.replace(/</g, '&lt;').replace(/>/g, '&gt;');
                }
                const langLabel = language || 'code';
                return '<div class="code-block-wrapper">' +
                    '<div class="code-block-header"><span class="code-lang">' + langLabel + '</span>' +
                    '<button class="copy-btn" onclick="copyCode(this)">Copy</button></div>' +
                    '<pre><code class="hljs language-' + language + '">' + highlighted + '</code></pre>' +
                    '<textarea style="display:none">' + src.replace(/</g, '&lt;') + '</textarea></div>';
            };

            renderer.listitem = function(text, task, checked) {
                const t = typeof text === 'object' ? text.text : text;
                const isTask = typeof text === 'object' ? text.task : task;
                const isChecked = typeof text === 'object' ? text.checked : checked;
                if (isTask) {
                    const cls = isChecked ? 'checked' : '';
                    const doneCls = isChecked ? ' done' : '';
                    return '<li class="task-list-item' + doneCls + '">' +
                        '<span class="task-checkbox ' + cls + '"></span>' +
                        '<span class="task-text">' + t + '</span></li>';
                }
                return '<li>' + t + '</li>';
            };

            renderer.list = function(body, ordered, start) {
                const b = typeof body === 'object' ? body.body : body;
                const isOrdered = typeof body === 'object' ? body.ordered : ordered;
                const items = typeof body === 'object' ? body.items : null;
                const hasTask = items ? items.some(i => i.task) : (b && b.includes('task-list-item'));
                if (hasTask) {
                    return '<ul class="task-list">' + b + '</ul>';
                }
                return isOrdered ? '<ol>' + b + '</ol>' : '<ul>' + b + '</ul>';
            };

            marked.setOptions({ renderer, gfm: true, breaks: false });

            function processCallouts(html) {
                return html.replace(/<blockquote>\\n?<p>\\[!(TIP|NOTE|WARNING|IMPORTANT)\\](.*?)<\\/p>/gi,
                    function(match, type, content) {
                        const t = type.toLowerCase();
                        const icons = { tip: '💡', note: 'ℹ️', warning: '⚠️', important: '🔴' };
                        return '<div class="callout callout-' + t + '">' +
                            '<span class="callout-icon">' + (icons[t] || 'ℹ️') + '</span>' +
                            '<div class="callout-content"><p>' + content;
                    });
            }

            let rendered = marked.parse(`\(escaped)`);
            rendered = processCallouts(rendered);
            document.getElementById('content').innerHTML = rendered;

            function copyCode(btn) {
                const wrapper = btn.closest('.code-block-wrapper');
                const textarea = wrapper.querySelector('textarea');
                const text = textarea.value.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
                window.webkit.messageHandlers.copyCode.postMessage(text);
                btn.textContent = 'Copied!';
                btn.classList.add('copied');
                setTimeout(function() { btn.textContent = 'Copy'; btn.classList.remove('copied'); }, 1500);
            }

            function reportHeight() {
                const h = document.body.scrollHeight;
                window.webkit.messageHandlers.contentHeight.postMessage(h);
            }
            new ResizeObserver(reportHeight).observe(document.body);
            setTimeout(reportHeight, 100);
            setTimeout(reportHeight, 500);
        </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        weak var webView: WKWebView?
        var parent: ChatMarkdownWebView
        var lastMarkdown: String = ""

        init(parent: ChatMarkdownWebView) {
            self.parent = parent
        }

        func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "copyCode", let code = message.body as? String {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code, forType: .string)
            } else if message.name == "contentHeight", let height = message.body as? CGFloat {
                DispatchQueue.main.async {
                    if height > 10 {
                        self.parent.contentHeight = height
                    }
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

// MARK: - Scroll Passthrough WebView

private class ScrollPassthroughWebView: WKWebView {
    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }
}
