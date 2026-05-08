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

// SVG icon library for slash menu
const IC = {
  h1: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 6v12M4 12h8M12 6v12"/><path d="M17 9.5 l1.5-2v9"/></svg>`,
  h2: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 6v12M4 12h8M12 6v12"/><path d="M15.5 9c0-1 .7-1.5 1.5-1.5s1.5.6 1.5 1.5c0 1.5-3 2.5-3 4.5h3"/></svg>`,
  h3: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 6v12M4 12h8M12 6v12"/><path d="M15.5 9c0-.8.7-1.5 1.5-1.5s1.5.7 1.5 1.5-.7 1.5-1.5 1.5 1.5.7 1.5 1.5-.7 1.5-1.5 1.5"/></svg>`,
  bulletList: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="5" cy="7" r="1.5" fill="currentColor" stroke="none"/><circle cx="5" cy="12" r="1.5" fill="currentColor" stroke="none"/><circle cx="5" cy="17" r="1.5" fill="currentColor" stroke="none"/><line x1="9" y1="7" x2="20" y2="7"/><line x1="9" y1="12" x2="20" y2="12"/><line x1="9" y1="17" x2="20" y2="17"/></svg>`,
  numberedList: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="10" y1="6" x2="20" y2="6"/><line x1="10" y1="12" x2="20" y2="12"/><line x1="10" y1="18" x2="20" y2="18"/><text x="4" y="8" font-size="7" fill="currentColor" stroke="none" font-weight="800" font-family="system-ui">1</text><text x="4" y="14" font-size="7" fill="currentColor" stroke="none" font-weight="800" font-family="system-ui">2</text><text x="4" y="20" font-size="7" fill="currentColor" stroke="none" font-weight="800" font-family="system-ui">3</text></svg>`,
  taskList: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="6" height="6" rx="1"/><path d="M5 8l1.5 1.5L9 7"/><line x1="13" y1="8" x2="21" y2="8"/><rect x="3" y="13" width="6" height="6" rx="1"/><line x1="13" y1="16" x2="21" y2="16"/></svg>`,
  blockquote: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 21c3 0 7-1 7-8V5c0-1.25-.756-2.017-2-2H4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2 1 0 1 0 1 1v1c0 1-1 2-2 2s-1 .008-1 1.031V21z"/><path d="M15 21c3 0 7-1 7-8V5c0-1.25-.757-2.017-2-2h-4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2h.75c0 2.25.25 4-2.75 4v3c0 1 0 1 1 1z"/></svg>`,
  codeBlock: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="18" rx="2"/><path d="M8 10l-3 2 3 2M16 10l3 2-3 2"/><line x1="13" y1="8" x2="11" y2="16"/></svg>`,
  table: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="3" y1="15" x2="21" y2="15"/><line x1="9" y1="3" x2="9" y2="21"/><line x1="15" y1="3" x2="15" y2="21"/></svg>`,
  divider: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round"><line x1="3" y1="12" x2="21" y2="12" stroke-width="2.5"/><line x1="3" y1="7" x2="21" y2="7" stroke-width="0.8" stroke-dasharray="2 2"/><line x1="3" y1="17" x2="21" y2="17" stroke-width="0.8" stroke-dasharray="2 2"/></svg>`,
  bold: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 4h8a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z"/><path d="M6 12h9a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z"/></svg>`,
  italic: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="19" y1="4" x2="10" y2="4"/><line x1="14" y1="20" x2="5" y2="20"/><line x1="15" y1="4" x2="9" y2="20"/></svg>`,
  highlight: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"/><path d="M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4Z"/></svg>`,
  linkTask: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 11l3 3L22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg>`,
  linkNote: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>`,
  linkReminder: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>`,
  linkKnowledge: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 18h6"/><path d="M10 22h4"/><path d="M15.09 14c.18-.98.65-1.74 1.41-2.5A4.65 4.65 0 0 0 18 8 6 6 0 0 0 6 8c0 1 .23 2.23 1.5 3.5A4.61 4.61 0 0 1 8.91 14"/></svg>`,
  linkProject: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 7a2 2 0 0 1 2-2h4l2 3h8a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2z"/></svg>`,
}

// --- Slash Commands Extension ---
const slashItems = [
  { title: 'Heading 1',     icon: IC.h1,           group: 'Text',   cmd: (e) => e.chain().focus().toggleHeading({ level: 1 }).run() },
  { title: 'Heading 2',     icon: IC.h2,           group: 'Text',   cmd: (e) => e.chain().focus().toggleHeading({ level: 2 }).run() },
  { title: 'Heading 3',     icon: IC.h3,           group: 'Text',   cmd: (e) => e.chain().focus().toggleHeading({ level: 3 }).run() },
  { title: 'Bullet List',   icon: IC.bulletList,   group: 'List',   cmd: (e) => e.chain().focus().toggleBulletList().run() },
  { title: 'Numbered List', icon: IC.numberedList, group: 'List',   cmd: (e) => e.chain().focus().toggleOrderedList().run() },
  { title: 'Task List',     icon: IC.taskList,     group: 'List',   cmd: (e) => e.chain().focus().toggleTaskList().run() },
  { title: 'Quote',         icon: IC.blockquote,   group: 'Block',  cmd: (e) => e.chain().focus().toggleBlockquote().run() },
  { title: 'Code Block',    icon: IC.codeBlock,    group: 'Block',  cmd: (e) => e.chain().focus().toggleCodeBlock().run() },
  { title: 'Table',         icon: IC.table,        group: 'Block',  cmd: (e) => e.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run() },
  { title: 'Divider',       icon: IC.divider,      group: 'Block',  cmd: (e) => e.chain().focus().setHorizontalRule().run() },
  { title: 'Bold',          icon: IC.bold,         group: 'Inline', cmd: (e) => e.chain().focus().toggleBold().run() },
  { title: 'Italic',        icon: IC.italic,       group: 'Inline', cmd: (e) => e.chain().focus().toggleItalic().run() },
  { title: 'Highlight',     icon: IC.highlight,    group: 'Inline', cmd: (e) => e.chain().focus().toggleHighlight().run() },
  { title: 'Link Task',     icon: IC.linkTask,     group: 'Link',   cmd: () => { window.webkit.messageHandlers.requestLinkInsert.postMessage('task') } },
  { title: 'Link Note',     icon: IC.linkNote,     group: 'Link',   cmd: () => { window.webkit.messageHandlers.requestLinkInsert.postMessage('note') } },
  { title: 'Link Reminder', icon: IC.linkReminder, group: 'Link',   cmd: () => { window.webkit.messageHandlers.requestLinkInsert.postMessage('reminder') } },
  { title: 'Link Project',  icon: IC.linkProject,  group: 'Link',   cmd: () => { window.webkit.messageHandlers.requestLinkInsert.postMessage('project') } },
  { title: 'Link Knowledge',icon: IC.linkKnowledge,group: 'Link',   cmd: () => { window.webkit.messageHandlers.requestLinkInsert.postMessage('knowledge') } },
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

function positionSlashMenu(rect) {
  if (!rect || !slashPopup) return
  const menuMaxH = 320
  const margin = 8
  const left = Math.max(margin, Math.min(rect.left, window.innerWidth - 220 - margin))
  slashPopup.style.left = left + 'px'
  const spaceBelow = window.innerHeight - rect.bottom - margin
  if (spaceBelow < menuMaxH && rect.top > menuMaxH) {
    slashPopup.style.top = 'auto'
    slashPopup.style.bottom = (window.innerHeight - rect.top + 4) + 'px'
  } else {
    slashPopup.style.top = (rect.bottom + 4) + 'px'
    slashPopup.style.bottom = 'auto'
  }
}

function renderSlashItems(items) {
  if (!slashPopup) return
  filteredItems = items
  slashSelectedIndex = Math.min(slashSelectedIndex, items.length - 1)
  if (slashSelectedIndex < 0) slashSelectedIndex = 0

  if (!items.length) {
    slashPopup.innerHTML = '<div class="slash-empty">No results</div>'
    return
  }

  let html = ''
  let lastGroup = null
  const isFiltering = items.length !== slashItems.length
  items.forEach((item, i) => {
    if (!isFiltering && item.group && item.group !== lastGroup) {
      html += `<div class="slash-group-label">${item.group}</div>`
      lastGroup = item.group
    }
    html += `<div class="slash-item${i === slashSelectedIndex ? ' selected' : ''}" data-index="${i}">
      <span class="slash-icon">${item.icon}</span>
      <span class="slash-label">${item.title}</span>
    </div>`
  })
  slashPopup.innerHTML = html

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
        if (slashPopup) { slashPopup.remove(); slashPopup = null }
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
          ).slice(0, 20)
        },
        render: () => {
          return {
            onStart(props) {
              createSlashPopup()
              slashSelectedIndex = 0
              slashCurrentRange = props.range
              positionSlashMenu(props.clientRect?.())
              renderSlashItems(props.items)
            },
            onUpdate(props) {
              slashCurrentRange = props.range
              positionSlashMenu(props.clientRect?.())
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
                  if (slashPopup) { slashPopup.remove(); slashPopup = null }
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

// --- Wiki Links Extension ---
let wikiLinkMap = {}

const wikiLinkPattern = /\[\[([^\]]+)\]\]/g
const wikiLinkPlugin = new Plugin({
  props: {
    decorations(state) {
      const decos = []
      state.doc.descendants((node, pos) => {
        if (!node.isText || !node.text) return
        wikiLinkPattern.lastIndex = 0
        let match
        while ((match = wikiLinkPattern.exec(node.text)) !== null) {
          const title = match[1]
          const attrs = { class: 'wiki-link' + (wikiLinkMap[title] ? ' wiki-link-resolved' : ''), 'data-title': title }
          decos.push(Decoration.inline(
            pos + match.index,
            pos + match.index + match[0].length,
            attrs
          ))
        }
      })
      return DecorationSet.create(state.doc, decos)
    }
  }
})

const WikiLinks = Extension.create({
  name: 'wikiLinks',
  addProseMirrorPlugins() {
    return [wikiLinkPlugin]
  }
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
    Link.configure({
      openOnClick: false,
      autolink: true,
      protocols: ['deepthink'],
      isAllowedUri: (url, ctx) => ctx.defaultValidate(url) || url.startsWith('deepthink://'),
    }),
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
    WikiLinks,
  ],
  content: '',
  onUpdate: ({ editor }) => {
    if (isSettingContent) return
    clearTimeout(debounceTimer)
    debounceTimer = setTimeout(() => {
      const md = editor.storage.markdown.getMarkdown()
      window.webkit.messageHandlers.contentChanged.postMessage(md)
      refreshDeadLinkStyles()
    }, 150)

    const wikiAcResult = getWikiQueryBeforeCursor()
    if (wikiAcResult) {
      showWikiAc(wikiAcResult.query, wikiAcResult.from)
    } else {
      hideWikiAc()
    }
  },
})

window.editorInstance = editor

document.getElementById('editor').addEventListener('click', (e) => {
  const el = e.target.closest('.wiki-link')
  if (el) {
    const title = el.getAttribute('data-title')
    if (title) {
      if (wikiLinkMap[title]) {
        window.webkit.messageHandlers.linkClicked.postMessage(wikiLinkMap[title])
      } else {
        window.webkit.messageHandlers.wikiLinkClicked.postMessage(title)
      }
    }
  }
})

window.setWikiLinks = function(linksJson) {
  wikiLinkMap = linksJson || {}
  const { tr } = editor.state
  editor.view.dispatch(tr)
}

// --- Shared helper ---
function escapeHtml(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
}

// --- Feature 1: Wiki link autocomplete ---
let wikiAcPopup = null
let wikiAcIndex = 0
let wikiAcItems = []
let wikiAcFrom = -1

function getWikiQueryBeforeCursor() {
  const { state } = editor
  const { from } = state.selection
  const textBefore = state.doc.textBetween(Math.max(0, from - 200), from, '\n', '\0')
  const match = textBefore.match(/\[\[([^\]]*)$/)
  if (!match) return null
  return { query: match[1], from: from - match[0].length }
}

function showWikiAc(query, fromPos) {
  wikiAcFrom = fromPos
  const titles = Object.keys(wikiLinkMap)
  wikiAcItems = (query
    ? titles.filter(t => t.toLowerCase().includes(query.toLowerCase()))
    : titles
  ).slice(0, 10)

  if (!wikiAcItems.length) { hideWikiAc(); return }

  if (!wikiAcPopup) {
    wikiAcPopup = document.createElement('div')
    wikiAcPopup.id = 'wiki-ac-menu'
    document.body.appendChild(wikiAcPopup)
  }
  wikiAcIndex = Math.max(0, Math.min(wikiAcIndex, wikiAcItems.length - 1))

  const coords = editor.view.coordsAtPos(editor.state.selection.from)
  const left = Math.min(coords.left, window.innerWidth - 260)
  wikiAcPopup.style.cssText = `position:fixed;left:${left}px;top:${coords.bottom + 4}px;`

  renderWikiAc()
}

function renderWikiAc() {
  if (!wikiAcPopup) return
  wikiAcPopup.innerHTML = wikiAcItems.map((t, i) =>
    `<div class="wiki-ac-item${i === wikiAcIndex ? ' selected' : ''}" data-idx="${i}">${escapeHtml(t)}</div>`
  ).join('')
  wikiAcPopup.querySelectorAll('.wiki-ac-item').forEach(el => {
    el.addEventListener('mouseenter', () => { wikiAcIndex = +el.dataset.idx; renderWikiAc() })
    el.addEventListener('mousedown', e => { e.preventDefault(); insertWikiAcLink(wikiAcItems[+el.dataset.idx]) })
  })
}

function hideWikiAc() {
  if (wikiAcPopup) { wikiAcPopup.remove(); wikiAcPopup = null }
  wikiAcFrom = -1
  wikiAcIndex = 0
}

function insertWikiAcLink(title) {
  const { from } = editor.state.selection
  editor.chain().focus().deleteRange({ from: wikiAcFrom, to: from }).insertContent(`[[${title}]]`).run()
  hideWikiAc()
}

document.addEventListener('keydown', (e) => {
  if (!wikiAcPopup) return
  if (e.key === 'ArrowDown') {
    e.preventDefault()
    wikiAcIndex = (wikiAcIndex + 1) % wikiAcItems.length
    renderWikiAc()
  } else if (e.key === 'ArrowUp') {
    e.preventDefault()
    wikiAcIndex = (wikiAcIndex - 1 + wikiAcItems.length) % wikiAcItems.length
    renderWikiAc()
  } else if (e.key === 'Enter') {
    e.preventDefault()
    if (wikiAcItems[wikiAcIndex]) insertWikiAcLink(wikiAcItems[wikiAcIndex])
  } else if (e.key === 'Escape') {
    hideWikiAc()
  }
})

// --- Feature 2: Hover link preview ---
let linkPreviewMap = {}
let previewEl = null
let previewTimer = null

window.setLinkPreviews = function(map) {
  linkPreviewMap = map || {}
}

document.getElementById('editor').addEventListener('mouseover', e => {
  const a = e.target.closest('a[href]')
  const wl = e.target.closest('.wiki-link')
  clearTimeout(previewTimer)

  let preview = null
  if (a) {
    const href = a.getAttribute('href')
    preview = linkPreviewMap[href]
  } else if (wl) {
    const title = wl.getAttribute('data-title')
    const uuid = wikiLinkMap[title]
    if (uuid) preview = linkPreviewMap[`deepthink://note/${uuid}`]
  }

  if (preview) {
    previewTimer = setTimeout(() => showLinkPreview(preview, e), 300)
  } else {
    hideLinkPreview()
  }
})

document.getElementById('editor').addEventListener('mouseout', e => {
  clearTimeout(previewTimer)
  const to = e.relatedTarget
  if (previewEl && previewEl.contains(to)) return
  hideLinkPreview()
})

function showLinkPreview(data, e) {
  hideLinkPreview()
  previewEl = document.createElement('div')
  previewEl.id = 'link-preview'
  previewEl.innerHTML = `
    <div class="lp-title">${escapeHtml(data.title || 'Untitled')}</div>
    ${data.subtitle ? `<div class="lp-subtitle">${escapeHtml(data.subtitle)}</div>` : ''}
    ${data.snippet ? `<div class="lp-snippet">${escapeHtml(data.snippet)}</div>` : ''}
  `
  document.body.appendChild(previewEl)
  const x = Math.min(e.clientX + 14, window.innerWidth - 260)
  const y = Math.min(e.clientY + 18, window.innerHeight - 120)
  previewEl.style.cssText = `position:fixed;left:${x}px;top:${y}px;`
  previewEl.addEventListener('mouseleave', hideLinkPreview)
}

function hideLinkPreview() {
  if (previewEl) { previewEl.remove(); previewEl = null }
}

// --- Feature 3: Dead link styling + clean ---
let deadLinkUUIDSet = new Set()

window.setDeadLinkUUIDs = function(uuids) {
  deadLinkUUIDSet = new Set(Array.isArray(uuids) ? uuids : [])
  refreshDeadLinkStyles()
}

function refreshDeadLinkStyles() {
  document.querySelectorAll('a[href*="deepthink://"]').forEach(a => {
    const href = a.getAttribute('href') || ''
    const m = href.match(/\/([0-9A-Fa-f-]{36})$/)
    a.classList.toggle('dead-link', !!(m && deadLinkUUIDSet.has(m[1])))
  })
}

window.cleanDeadLinks = function() {
  const { tr, doc, schema } = editor.state
  let changed = false
  doc.descendants((node, pos) => {
    if (!node.isText) return
    const linkMark = node.marks.find(m => m.type.name === 'link')
    if (!linkMark) return
    const href = linkMark.attrs.href || ''
    const m = href.match(/deepthink:\/\/[^/]+\/([0-9A-Fa-f-]{36})/)
    if (m && deadLinkUUIDSet.has(m[1])) {
      tr.removeMark(pos, pos + node.nodeSize, schema.marks.link)
      changed = true
    }
  })
  if (changed) editor.view.dispatch(tr)
  deadLinkUUIDSet = new Set()
  refreshDeadLinkStyles()
}

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
window.insertDeepLink = function(text, url) {
  if (!window.editorInstance) return
  window.editorInstance.chain().focus().insertContent(
    { type: 'text', text: text, marks: [{ type: 'link', attrs: { href: url } }] }
  ).run()
}

window.setMarkdown = function(md) {
  isSettingContent = true
  editor.commands.setContent(md)
  isSettingContent = false
  setTimeout(() => refreshDeadLinkStyles(), 50)
}

window.getMarkdown = function() {
  return editor.storage.markdown.getMarkdown()
}

window.setReadOnly = function(readOnly) {
  editor.setEditable(!readOnly)
  const toolbar = document.getElementById('toolbar')
  if (toolbar) toolbar.style.display = readOnly ? 'none' : ''
}

window.webkit.messageHandlers.editorReady.postMessage('ready')
