import { Editor, Extension } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'
import Link from '@tiptap/extension-link'
import TaskList from '@tiptap/extension-task-list'
import TaskItem from '@tiptap/extension-task-item'
import Placeholder from '@tiptap/extension-placeholder'
import Underline from '@tiptap/extension-underline'
import Highlight from '@tiptap/extension-highlight'
import TextAlign from '@tiptap/extension-text-align'
import { Table } from '@tiptap/extension-table'
import { TableRow } from '@tiptap/extension-table-row'
import { TableCell } from '@tiptap/extension-table-cell'
import { TableHeader } from '@tiptap/extension-table-header'
import Suggestion from '@tiptap/suggestion'
import { Markdown } from 'tiptap-markdown'
import { Plugin, PluginKey } from '@tiptap/pm/state'
import { Decoration, DecorationSet } from '@tiptap/pm/view'

// --- Slash Commands Extension ---
const slashItems = [
  { title: 'Heading 1', icon: 'H1', cmd: (e) => e.chain().focus().toggleHeading({ level: 1 }).run() },
  { title: 'Heading 2', icon: 'H2', cmd: (e) => e.chain().focus().toggleHeading({ level: 2 }).run() },
  { title: 'Heading 3', icon: 'H3', cmd: (e) => e.chain().focus().toggleHeading({ level: 3 }).run() },
  { title: 'Bullet List', icon: '•', cmd: (e) => e.chain().focus().toggleBulletList().run() },
  { title: 'Numbered List', icon: '1.', cmd: (e) => e.chain().focus().toggleOrderedList().run() },
  { title: 'Task List', icon: '☐', cmd: (e) => e.chain().focus().toggleTaskList().run() },
  { title: 'Blockquote', icon: '"', cmd: (e) => e.chain().focus().toggleBlockquote().run() },
  { title: 'Code Block', icon: '</>', cmd: (e) => e.chain().focus().toggleCodeBlock().run() },
  { title: 'Table', icon: '⊞', cmd: (e) => e.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run() },
  { title: 'Divider', icon: '—', cmd: (e) => e.chain().focus().setHorizontalRule().run() },
  { title: 'Bold', icon: 'B', cmd: (e) => e.chain().focus().toggleBold().run() },
  { title: 'Italic', icon: 'I', cmd: (e) => e.chain().focus().toggleItalic().run() },
  { title: 'Highlight', icon: '✦', cmd: (e) => e.chain().focus().toggleHighlight().run() },
]

let slashPopup = null
let slashSelectedIndex = 0
let filteredItems = []
let slashCurrentRange = null

function createSlashPopup() {
  if (slashPopup) slashPopup.remove()
  slashPopup = document.createElement('div')
  slashPopup.id = 'slash-menu'
  document.body.appendChild(slashPopup)
  return slashPopup
}

function renderSlashItems(items) {
  if (!slashPopup) return
  filteredItems = items
  slashSelectedIndex = Math.min(slashSelectedIndex, items.length - 1)
  if (slashSelectedIndex < 0) slashSelectedIndex = 0
  slashPopup.innerHTML = items.length
    ? items.map((item, i) =>
      `<div class="slash-item${i === slashSelectedIndex ? ' selected' : ''}" data-index="${i}">
        <span class="slash-icon">${item.icon}</span>
        <span class="slash-label">${item.title}</span>
      </div>`
    ).join('')
    : '<div class="slash-empty">No results</div>'

  slashPopup.querySelectorAll('.slash-item').forEach(el => {
    el.addEventListener('mouseenter', () => {
      slashSelectedIndex = parseInt(el.dataset.index)
      renderSlashItems(filteredItems)
    })
    el.addEventListener('mousedown', (e) => {
      e.preventDefault()
      const idx = parseInt(el.dataset.index)
      if (filteredItems[idx]) {
        if (slashCurrentRange) {
          editor.chain().focus().deleteRange(slashCurrentRange).run()
        }
        filteredItems[idx].cmd(editor)
      }
    })
  })
}

const SlashCommands = Extension.create({
  name: 'slashCommands',
  addOptions() {
    return {
      suggestion: {
        char: '/',
        startOfLine: false,
        items: ({ query }) => {
          return slashItems.filter(item =>
            item.title.toLowerCase().includes(query.toLowerCase())
          ).slice(0, 10)
        },
        render: () => {
          return {
            onStart(props) {
              createSlashPopup()
              slashSelectedIndex = 0
              slashCurrentRange = props.range
              const rect = props.clientRect?.()
              if (rect && slashPopup) {
                slashPopup.style.top = rect.bottom + 4 + 'px'
                slashPopup.style.left = rect.left + 'px'
              }
              renderSlashItems(props.items)
            },
            onUpdate(props) {
              slashCurrentRange = props.range
              const rect = props.clientRect?.()
              if (rect && slashPopup) {
                slashPopup.style.top = rect.bottom + 4 + 'px'
                slashPopup.style.left = rect.left + 'px'
              }
              renderSlashItems(props.items)
            },
            onKeyDown(props) {
              if (props.event.key === 'ArrowDown') {
                slashSelectedIndex = (slashSelectedIndex + 1) % filteredItems.length
                renderSlashItems(filteredItems)
                return true
              }
              if (props.event.key === 'ArrowUp') {
                slashSelectedIndex = (slashSelectedIndex - 1 + filteredItems.length) % filteredItems.length
                renderSlashItems(filteredItems)
                return true
              }
              if (props.event.key === 'Enter') {
                if (filteredItems[slashSelectedIndex]) {
                  if (slashCurrentRange) {
                    editor.chain().focus().deleteRange(slashCurrentRange).run()
                  }
                  filteredItems[slashSelectedIndex].cmd(editor)
                }
                return true
              }
              if (props.event.key === 'Escape') {
                if (slashPopup) slashPopup.remove()
                slashPopup = null
                return true
              }
              return false
            },
            onExit() {
              if (slashPopup) slashPopup.remove()
              slashPopup = null
              slashCurrentRange = null
            },
          }
        },
      },
    }
  },
  addProseMirrorPlugins() {
    return [
      Suggestion({
        editor: this.editor,
        ...this.options.suggestion,
      }),
    ]
  },
})

// --- Search & Replace Extension ---
const searchPluginKey = new PluginKey('searchReplace')

const SearchReplace = Extension.create({
  name: 'searchReplace',
  addStorage() {
    return { searchTerm: '', replaceTerm: '', results: [], currentIndex: 0 }
  },
  addKeyboardShortcuts() {
    return {
      'Mod-f': () => { toggleSearchBar(); return true },
      'Mod-h': () => { toggleSearchBar(true); return true },
    }
  },
  addProseMirrorPlugins() {
    const ext = this
    return [
      new Plugin({
        key: searchPluginKey,
        state: {
          init() { return DecorationSet.empty },
          apply(tr, oldSet) {
            const s = ext.storage
            if (!s.searchTerm) return DecorationSet.empty
            const doc = tr.doc
            const decos = []
            const term = s.searchTerm.toLowerCase()
            s.results = []
            doc.descendants((node, pos) => {
              if (!node.isText) return
              const text = node.text.toLowerCase()
              let idx = text.indexOf(term)
              while (idx !== -1) {
                const from = pos + idx
                const to = from + s.searchTerm.length
                s.results.push({ from, to })
                idx = text.indexOf(term, idx + 1)
              }
            })
            s.results.forEach((r, i) => {
              const cls = i === s.currentIndex ? 'search-highlight-current' : 'search-highlight'
              decos.push(Decoration.inline(r.from, r.to, { class: cls }))
            })
            return DecorationSet.create(doc, decos)
          },
        },
        props: {
          decorations(state) { return this.getState(state) },
        },
      }),
    ]
  },
})

function triggerSearchUpdate() {
  const { tr } = editor.state
  editor.view.dispatch(tr.setMeta('searchReplace', true))
  updateSearchCount()
}

function updateSearchCount() {
  const s = editor.storage.searchReplace
  const countEl = document.getElementById('search-count')
  if (countEl) {
    countEl.textContent = s.results.length ? `${s.currentIndex + 1}/${s.results.length}` : 'No results'
  }
}

function scrollToResult() {
  const s = editor.storage.searchReplace
  if (!s.results.length) return
  const r = s.results[s.currentIndex]
  if (r) {
    editor.commands.setTextSelection(r)
    const domPos = editor.view.domAtPos(r.from)
    if (domPos?.node) {
      const el = domPos.node.nodeType === 3 ? domPos.node.parentElement : domPos.node
      el?.scrollIntoView({ block: 'center', behavior: 'smooth' })
    }
  }
}

function searchNext() {
  const s = editor.storage.searchReplace
  if (!s.results.length) return
  s.currentIndex = (s.currentIndex + 1) % s.results.length
  triggerSearchUpdate()
  scrollToResult()
}

function searchPrev() {
  const s = editor.storage.searchReplace
  if (!s.results.length) return
  s.currentIndex = (s.currentIndex - 1 + s.results.length) % s.results.length
  triggerSearchUpdate()
  scrollToResult()
}

function replaceCurrent() {
  const s = editor.storage.searchReplace
  if (!s.results.length) return
  const r = s.results[s.currentIndex]
  if (!r) return
  editor.chain().focus().setTextSelection(r).insertContent(s.replaceTerm).run()
  triggerSearchUpdate()
}

function replaceAll() {
  const s = editor.storage.searchReplace
  if (!s.results.length) return
  const sorted = [...s.results].sort((a, b) => b.from - a.from)
  let chain = editor.chain()
  sorted.forEach(r => { chain = chain.setTextSelection(r).insertContent(s.replaceTerm) })
  chain.run()
  s.searchTerm = ''
  triggerSearchUpdate()
  closeSearchBar()
}

function toggleSearchBar(withReplace = false) {
  let bar = document.getElementById('search-bar')
  if (bar) {
    const replaceRow = document.getElementById('replace-row')
    if (withReplace && replaceRow.style.display === 'none') {
      replaceRow.style.display = 'flex'
    } else if (!withReplace && bar.style.display !== 'none') {
      closeSearchBar()
    }
    document.getElementById('search-input')?.focus()
    return
  }
  bar = document.createElement('div')
  bar.id = 'search-bar'
  bar.innerHTML = `
    <div class="search-row">
      <input type="text" id="search-input" placeholder="Search..." spellcheck="false" />
      <span id="search-count">No results</span>
      <button class="search-btn" id="search-prev" title="Previous (⇧Enter)">▲</button>
      <button class="search-btn" id="search-next" title="Next (Enter)">▼</button>
      <button class="search-btn" id="search-close" title="Close (Esc)">✕</button>
    </div>
    <div class="search-row" id="replace-row" style="display:${withReplace ? 'flex' : 'none'}">
      <input type="text" id="replace-input" placeholder="Replace..." spellcheck="false" />
      <button class="search-btn" id="replace-one" title="Replace">Replace</button>
      <button class="search-btn" id="replace-all" title="Replace All">All</button>
    </div>
  `
  document.body.insertBefore(bar, document.getElementById('editor'))

  const searchInput = document.getElementById('search-input')
  const replaceInput = document.getElementById('replace-input')

  searchInput.addEventListener('input', () => {
    editor.storage.searchReplace.searchTerm = searchInput.value
    editor.storage.searchReplace.currentIndex = 0
    triggerSearchUpdate()
    scrollToResult()
  })
  replaceInput.addEventListener('input', () => {
    editor.storage.searchReplace.replaceTerm = replaceInput.value
  })
  searchInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { e.shiftKey ? searchPrev() : searchNext(); e.preventDefault() }
    if (e.key === 'Escape') { closeSearchBar(); editor.commands.focus() }
  })
  replaceInput.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') { closeSearchBar(); editor.commands.focus() }
  })
  document.getElementById('search-prev').addEventListener('click', searchPrev)
  document.getElementById('search-next').addEventListener('click', searchNext)
  document.getElementById('search-close').addEventListener('click', () => { closeSearchBar(); editor.commands.focus() })
  document.getElementById('replace-one').addEventListener('click', replaceCurrent)
  document.getElementById('replace-all').addEventListener('click', replaceAll)

  searchInput.focus()
}

function closeSearchBar() {
  const bar = document.getElementById('search-bar')
  if (bar) bar.remove()
  editor.storage.searchReplace.searchTerm = ''
  editor.storage.searchReplace.results = []
  editor.storage.searchReplace.currentIndex = 0
  triggerSearchUpdate()
}

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
    Table.configure({ resizable: true, handleWidth: 5, cellMinWidth: 60, lastColumnResizable: true }),
    TableRow,
    TableCell,
    TableHeader,
    Markdown.configure({ html: true, transformPastedText: true, transformCopiedText: true }),
    SlashCommands,
    SearchReplace,
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
    case 'insertTable': chain.insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run(); break
    case 'addColAfter': chain.addColumnAfter().run(); break
    case 'addRowAfter': chain.addRowAfter().run(); break
    case 'deleteCol': chain.deleteColumn().run(); break
    case 'deleteRow': chain.deleteRow().run(); break
    case 'deleteTable': chain.deleteTable().run(); break
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
      case 'insertTable': active = editor.isActive('table'); break
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
