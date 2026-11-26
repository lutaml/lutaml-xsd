import { describe, it, expect, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useSearch } from '../useSearch'
import { useSchemaStore } from '@/stores/schemaStore'
import type { SchemaData } from '@/types'

const data = {
  metadata: { name: 'pkg' },
  namespaces: [],
  schemas: [
    {
      id: 'entry',
      name: 'entry',
      location: 'entry.xsd',
      is_entrypoint: true,
      elements: [
        { id: 'e-Plain', name: 'Plain', type: 'Plain' },
        { id: 'e-plain-sub', name: 'PlainSub', type: 'Plain' },
        { id: 'e-PlainDeprecated', name: 'PlainDeprecated', type: 'Plain', deprecated: true },
      ],
      complex_types: [
        { id: 'ct-Plain', name: 'Plain', deprecated: false },
        { id: 'ct-Plainish', name: 'Plainish' },
      ],
      simple_types: [],
      groups: [],
      attribute_groups: [],
      attributes: [],
    },
    {
      id: 'other',
      name: 'other',
      location: 'other.xsd',
      is_entrypoint: false,
      elements: [],
      complex_types: [
        { id: 'ct-PlainOther', name: 'Plain', deprecated: false },
        { id: 'ct-PlainDeprecatedOther', name: 'PlainOther', deprecated: true },
      ],
      simple_types: [],
      groups: [],
      attribute_groups: [],
      attributes: [],
    },
  ],
} as unknown as SchemaData

describe('useSearch ranking', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    const store = useSchemaStore()
    store.$patch({ schemaData: data })
  })

  it('ranks exact-name entrypoint types above same-name non-entrypoint types', () => {
    const search = useSearch()
    search.query.value = 'Plain'
    search.search()
    const ids = search.results.value.map(r => r.id)
    expect(ids.indexOf('ct-Plain')).toBeLessThan(ids.indexOf('ct-PlainOther'))
  })

  it('demotes deprecated components', () => {
    const search = useSearch()
    search.query.value = 'Plain'
    search.search()
    const ids = search.results.value.map(r => r.id)
    const deprecatedIdx = ids.indexOf('e-PlainDeprecated')
    const plainIdx = ids.indexOf('e-Plain')
    expect(deprecatedIdx).toBeGreaterThan(plainIdx)
  })

  it('ranks exact above prefix above substring', () => {
    const search = useSearch()
    search.query.value = 'Plain'
    search.search()
    const ids = search.results.value.map(r => r.id)
    // exact 'Plain' components first, prefix 'PlainSub' before substring 'Plainish'
    expect(ids.indexOf('e-PlainSub')).toBeLessThan(ids.indexOf('ct-Plainish'))
  })
})
