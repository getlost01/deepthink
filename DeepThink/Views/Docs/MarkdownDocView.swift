import SwiftUI
import WebKit

struct MarkdownDocView: NSViewRepresentable {
    let markdown: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        loadMarkdown(webView: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        loadMarkdown(webView: webView)
    }

    private func loadMarkdown(webView: WKWebView) {
        let escaped = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css">
        <script src="https://cdnjs.cloudflare.com/ajax/libs/marked/12.0.1/marked.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
        <style>
            * { box-sizing: border-box; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
                font-size: 13px;
                line-height: 1.6;
                color: #e0e0e0;
                background: transparent;
                padding: 20px 24px;
                margin: 0;
                max-width: 800px;
            }
            h1 { font-size: 24px; font-weight: 700; margin: 24px 0 12px; color: #f0f0f0; border-bottom: 1px solid #333; padding-bottom: 8px; }
            h2 { font-size: 20px; font-weight: 600; margin: 20px 0 10px; color: #f0f0f0; }
            h3 { font-size: 16px; font-weight: 600; margin: 16px 0 8px; color: #e8e8e8; }
            h4, h5, h6 { font-size: 14px; font-weight: 600; margin: 12px 0 6px; color: #e0e0e0; }
            p { margin: 8px 0; }
            a { color: #58a6ff; text-decoration: none; }
            a:hover { text-decoration: underline; }
            code {
                font-family: 'SF Mono', Menlo, monospace;
                font-size: 12px;
                background: #1e1e2e;
                padding: 2px 5px;
                border-radius: 4px;
            }
            pre {
                background: #1e1e2e;
                border-radius: 8px;
                padding: 14px;
                overflow-x: auto;
                margin: 12px 0;
                border: 1px solid #2a2a3a;
            }
            pre code {
                background: none;
                padding: 0;
                font-size: 12px;
                line-height: 1.5;
            }
            blockquote {
                border-left: 3px solid #444;
                margin: 12px 0;
                padding: 4px 16px;
                color: #aaa;
            }
            table {
                border-collapse: collapse;
                width: 100%;
                margin: 12px 0;
            }
            th, td {
                border: 1px solid #333;
                padding: 8px 12px;
                text-align: left;
            }
            th { background: #1e1e2e; font-weight: 600; }
            tr:nth-child(even) { background: rgba(255,255,255,0.02); }
            ul, ol { padding-left: 24px; margin: 8px 0; }
            li { margin: 4px 0; }
            hr { border: none; border-top: 1px solid #333; margin: 20px 0; }
            img { max-width: 100%; border-radius: 8px; margin: 8px 0; }
            .task-list-item { list-style-type: none; }
            .task-list-item input { margin-right: 8px; }
        </style>
        </head>
        <body>
        <div id="content"></div>
        <script>
            marked.setOptions({
                highlight: function(code, lang) {
                    if (lang && hljs.getLanguage(lang)) {
                        return hljs.highlight(code, { language: lang }).value;
                    }
                    return hljs.highlightAuto(code).value;
                },
                gfm: true,
                breaks: false
            });
            document.getElementById('content').innerHTML = marked.parse(`\(escaped)`);
        </script>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: nil)
    }
}

struct CodeDocView: NSViewRepresentable {
    let code: String
    let language: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.setValue(false, forKey: "drawsBackground")
        loadCode(webView: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        loadCode(webView: webView)
    }

    private func loadCode(webView: WKWebView) {
        let escaped = code
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css">
        <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
        <style>
            body {
                margin: 0;
                padding: 0;
                background: transparent;
                font-family: 'SF Mono', Menlo, monospace;
                font-size: 12px;
            }
            pre {
                margin: 0;
                padding: 16px;
                counter-reset: line;
            }
            code {
                line-height: 1.5;
            }
        </style>
        </head>
        <body>
        <pre><code class="language-\(language)">\(escaped)</code></pre>
        <script>hljs.highlightAll();</script>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: nil)
    }
}
