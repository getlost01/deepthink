import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'
import Link from '@tiptap/extension-link'
import TaskList from '@tiptap/extension-task-list'
import TaskItem from '@tiptap/extension-task-item'
import Placeholder from '@tiptap/extension-placeholder'
import Underline from '@tiptap/extension-underline'
import Highlight from '@tiptap/extension-highlight'
import TextAlign from '@tiptap/extension-text-align'
import { Markdown } from 'tiptap-markdown'

let debounceTimer = null
let isSettingContent = false

const editor = new Editor({
  element: document.getElementById('editor'),
  extensions: [
    StarterKit.configure({
      heading: { levels: [1, 2, 3] },
    }),
    Link.configure({ openOnClick: false, autolink: true }),
    TaskList,
    TaskItem.configure({ nested: true }),
    Underline,
    Highlight.configure({ multicolor: false }),
    TextAlign.configure({ types: ['heading', 'paragraph'] }),
    Placeholder.configure({ placeholder: 'Write something amazing...' }),
    Markdown.configure({ html: false, transformPastedText: true, transformCopiedText: true }),
  ],
  content: '',
  onUpdate: ({ editor }) => {
    if (isSettingContent) return
    clearTimeout(debounceTimer)
    debounceTimer = setTimeout(() => {
      const md = editor.storage.markdown.getMarkdown()
      window.webkit.messageHandlers.contentChanged.postMessage(md)
    }, 150)
  },
})

window.editorInstance = editor

// Link popover
function showLinkInput() {
  const existing = document.getElementById('link-popover')
  if (existing) { existing.remove(); return }

  const sel = window.getSelection()
  if (!sel.rangeCount) return

  const range = sel.getRangeAt(0)
  const rect = range.getBoundingClientRect()

  const popover = document.createElement('div')
  popover.id = 'link-popover'
  popover.innerHTML = `
    <input type="url" id="link-input" placeholder="https://example.com" value="${editor.getAttributes('link').href || 'https://'}" />
    <button id="link-apply">Apply</button>
    <button id="link-remove" style="color:var(--error, #ff453a)">Remove</button>
  `
  popover.style.cssText = `
    position:fixed; top:${rect.bottom + 6}px; left:${Math.max(8, rect.left)}px;
    background:var(--toolbar-bg); border:1px solid var(--border);
    border-radius:8px; padding:6px 8px; display:flex; gap:6px; align-items:center;
    z-index:100; backdrop-filter:blur(20px); -webkit-backdrop-filter:blur(20px);
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  `
  document.body.appendChild(popover)

  const input = document.getElementById('link-input')
  input.style.cssText = `
    border:1px solid var(--border); background:var(--block-bg); color:var(--text);
    border-radius:5px; padding:4px 8px; font-size:12px; width:220px; outline:none;
    font-family:inherit;
  `
  const btnStyle = `border:none; background:var(--accent); color:white; border-radius:5px;
    padding:4px 10px; font-size:11px; cursor:pointer; font-weight:600;`
  document.getElementById('link-apply').style.cssText = btnStyle
  document.getElementById('link-remove').style.cssText = btnStyle.replace('var(--accent)', 'transparent') + 'color:var(--text-dim);'

  input.focus()
  input.select()

  document.getElementById('link-apply').onclick = () => {
    const url = input.value.trim()
    if (url) {
      editor.chain().focus().setLink({ href: url }).run()
    }
    popover.remove()
  }
  document.getElementById('link-remove').onclick = () => {
    editor.chain().focus().unsetLink().run()
    popover.remove()
  }
  input.onkeydown = (e) => {
    if (e.key === 'Enter') { document.getElementById('link-apply').click() }
    if (e.key === 'Escape') { popover.remove(); editor.commands.focus() }
  }

  const dismiss = (e) => {
    if (!popover.contains(e.target)) { popover.remove(); document.removeEventListener('mousedown', dismiss) }
  }
  setTimeout(() => document.addEventListener('mousedown', dismiss), 10)
}

// Toolbar actions
document.getElementById('toolbar').addEventListener('click', (e) => {
  const btn = e.target.closest('.tb-btn')
  if (!btn) return
  const action = btn.dataset.action
  const chain = editor.chain().focus()

  switch (action) {
    case 'bold': chain.toggleBold().run(); break
    case 'italic': chain.toggleItalic().run(); break
    case 'underline': chain.toggleUnderline().run(); break
    case 'strike': chain.toggleStrike().run(); break
    case 'code': chain.toggleCode().run(); break
    case 'highlight': chain.toggleHighlight().run(); break
    case 'h1': chain.toggleHeading({ level: 1 }).run(); break
    case 'h2': chain.toggleHeading({ level: 2 }).run(); break
    case 'h3': chain.toggleHeading({ level: 3 }).run(); break
    case 'body': chain.setParagraph().run(); break
    case 'bulletList': chain.toggleBulletList().run(); break
    case 'orderedList': chain.toggleOrderedList().run(); break
    case 'taskList': chain.toggleTaskList().run(); break
    case 'codeBlock': chain.toggleCodeBlock().run(); break
    case 'blockquote': chain.toggleBlockquote().run(); break
    case 'hr': chain.setHorizontalRule().run(); break
    case 'alignLeft': chain.setTextAlign('left').run(); break
    case 'alignCenter': chain.setTextAlign('center').run(); break
    case 'alignRight': chain.setTextAlign('right').run(); break
    case 'link': showLinkInput(); return
  }
  updateToolbarState()
})

function updateToolbarState() {
  document.querySelectorAll('.tb-btn').forEach(btn => {
    const action = btn.dataset.action
    let active = false
    switch (action) {
      case 'bold': active = editor.isActive('bold'); break
      case 'italic': active = editor.isActive('italic'); break
      case 'underline': active = editor.isActive('underline'); break
      case 'strike': active = editor.isActive('strike'); break
      case 'code': active = editor.isActive('code'); break
      case 'highlight': active = editor.isActive('highlight'); break
      case 'h1': active = editor.isActive('heading', { level: 1 }); break
      case 'h2': active = editor.isActive('heading', { level: 2 }); break
      case 'h3': active = editor.isActive('heading', { level: 3 }); break
      case 'bulletList': active = editor.isActive('bulletList'); break
      case 'orderedList': active = editor.isActive('orderedList'); break
      case 'taskList': active = editor.isActive('taskList'); break
      case 'codeBlock': active = editor.isActive('codeBlock'); break
      case 'blockquote': active = editor.isActive('blockquote'); break
      case 'link': active = editor.isActive('link'); break
      case 'alignLeft': active = editor.isActive({ textAlign: 'left' }); break
      case 'alignCenter': active = editor.isActive({ textAlign: 'center' }); break
      case 'alignRight': active = editor.isActive({ textAlign: 'right' }); break
    }
    btn.classList.toggle('active', active)
  })
}

editor.on('selectionUpdate', updateToolbarState)
editor.on('transaction', updateToolbarState)

// Swift → JS
window.setMarkdown = function(md) {
  isSettingContent = true
  editor.commands.setContent(md)
  isSettingContent = false
}

window.getMarkdown = function() {
  return editor.storage.markdown.getMarkdown()
}

window.webkit.messageHandlers.editorReady.postMessage('ready')
