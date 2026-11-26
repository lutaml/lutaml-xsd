import { ref, computed, watch } from 'vue'
import FlexSearch from 'flexsearch'
import { useSchemaStore } from '@/stores/schemaStore'
import { useUiStore } from '@/stores/uiStore'

interface SearchResult {
  id: string
  type: 'complex' | 'simple' | 'element'
  name: string
  schemaName: string
  schemaId: string
  doc?: string
  deprecated?: boolean
}

// Exact-name matches outrank prefix matches, prefix outranks
// substring; entrypoint schemas rank above the rest; deprecated
// components sink below equivalent non-deprecated ones; types edge
// out elements as a tiebreak.
const SCORE_EXACT = 100
const SCORE_PREFIX = 60
const SCORE_SUBSTRING = 30
const SCORE_ENTRYPOINT = 15
const SCORE_DEPRECATED = -40

export function useSearch() {
  const schemaStore = useSchemaStore()
  const uiStore = useUiStore()

  const query = ref('')
  const results = ref<SearchResult[]>([])
  const isSearching = ref(false)
  let debounceTimer: ReturnType<typeof setTimeout> | null = null

  // FlexSearch indexes - using any to avoid complex type issues
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const typeIndex: any = new (FlexSearch as any).Document({
    document: {
      id: 'id',
      index: ['name', 'doc'],
      store: ['id', 'type', 'name', 'schemaName', 'schemaId', 'doc', 'deprecated']
    },
    tokenize: 'forward',
    resolution: 9
  })

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const elementIndex: any = new (FlexSearch as any).Document({
    document: {
      id: 'id',
      index: ['name', 'doc'],
      store: ['id', 'type', 'name', 'schemaName', 'schemaId', 'doc', 'deprecated']
    },
    tokenize: 'forward',
    resolution: 9
  })

  function buildIndexes() {
    // Index complex types
    schemaStore.allComplexTypes.forEach(t => {
      typeIndex.add({
        id: t.id,
        type: 'complex',
        name: t.name,
        schemaName: t.schemaName,
        schemaId: t.schemaId,
        doc: t.documentation,
        deprecated: Boolean(t.deprecated)
      })
    })

    // Index simple types
    schemaStore.allSimpleTypes.forEach(t => {
      typeIndex.add({
        id: t.id,
        type: 'simple',
        name: t.name,
        schemaName: t.schemaName,
        schemaId: t.schemaId,
        doc: t.documentation,
        deprecated: Boolean(t.deprecated)
      })
    })

    // Index elements
    schemaStore.allElements.forEach(e => {
      elementIndex.add({
        id: e.id,
        type: 'element',
        name: e.name,
        schemaName: e.schemaName,
        schemaId: e.schemaId,
        doc: e.documentation,
        deprecated: Boolean((e as unknown as { deprecated?: boolean }).deprecated)
      })
    })
  }

  function search() {
    if (!query.value.trim()) {
      results.value = []
      return
    }

    isSearching.value = true

    const typeResults = typeIndex.search(query.value, { limit: 30, enrich: true })
    const elementResults = elementIndex.search(query.value, { limit: 20, enrich: true })

    const combined: SearchResult[] = []
    const seen = new Set<string>()

    // Process type results
    if (Array.isArray(typeResults)) {
      typeResults.forEach((field: { result: Array<{ id: string; doc?: SearchResult }> }) => {
        if (field.result && Array.isArray(field.result)) {
          field.result.forEach((r: { id: string; doc?: SearchResult }) => {
            if (r.doc && !seen.has(r.id)) {
              seen.add(r.id)
              combined.push(r.doc)
            }
          })
        }
      })
    }

    // Process element results
    if (Array.isArray(elementResults)) {
      elementResults.forEach((field: { result: Array<{ id: string; doc?: SearchResult }> }) => {
        if (field.result && Array.isArray(field.result)) {
          field.result.forEach((r: { id: string; doc?: SearchResult }) => {
            if (r.doc && !seen.has(r.id)) {
              seen.add(r.id)
              combined.push(r.doc)
            }
          })
        }
      })
    }

    results.value = combined
      .map(r => ({ result: r, score: scoreResult(r, query.value) }))
      .sort((a, b) => b.score - a.score || a.result.name.localeCompare(b.result.name))
      .map(e => e.result)
      .slice(0, 50)
    isSearching.value = false
  }

  function scoreResult(r: SearchResult, q: string): number {
    const name = r.name.toLowerCase()
    const needle = q.trim().toLowerCase()
    let score = 0

    if (name === needle) score += SCORE_EXACT
    else if (name.startsWith(needle)) score += SCORE_PREFIX
    else if (name.includes(needle)) score += SCORE_SUBSTRING

    const schema = schemaStore.getSchemaById(r.schemaId)
    if (schema?.is_entrypoint) score += SCORE_ENTRYPOINT

    if (r.deprecated) score += SCORE_DEPRECATED

    if (r.type === 'complex') score += 4
    else if (r.type === 'simple') score += 3

    return score
  }

  function debouncedSearch() {
    if (debounceTimer) clearTimeout(debounceTimer)
    debounceTimer = setTimeout(search, 150)
  }

  watch(query, debouncedSearch)

  // Watch for schema data changes to rebuild indexes
  watch(
    () => schemaStore.schemaData,
    () => {
      buildIndexes()
    },
    { immediate: true }
  )

  const hasResults = computed(() => results.value.length > 0)

  function selectResult(result: SearchResult) {
    schemaStore.selectSchema(result.schemaId)
    schemaStore.selectType(result.id)
    uiStore.openDetailPanel()
    closeSearch()
  }

  function closeSearch() {
    uiStore.closeSearch()
    query.value = ''
    results.value = []
  }

  return {
    query,
    results,
    isSearching,
    hasResults,
    search,
    selectResult,
    closeSearch,
    buildIndexes
  }
}
