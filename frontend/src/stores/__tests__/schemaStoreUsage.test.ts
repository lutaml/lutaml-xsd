import { describe, it, expect, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useSchemaStore } from '../schemaStore'
import type { SchemaData } from '@/types'

const mockSchemaData = {
  metadata: { name: 'test-package' },
  namespaces: [],
  hierarchy: {
    Derived: { chain: ['Derived --> Base'], mermaid: [] },
  },
  usage: {
    Base: [
      { by: 'derivation', name: 'Derived', schema: 'biblio' },
      { by: 'element', name: 'root', schema: 'biblio' },
    ],
    TypedUri: [
      { by: 'particle', name: 'TypedTitleString', schema: 'other' },
    ],
  },
} as unknown as SchemaData

describe('schemaStore usage getter', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('exposes the usage map from the payload', () => {
    const store = useSchemaStore()
    store.$patch({ schemaData: mockSchemaData })
    expect(store.usage).toEqual(mockSchemaData.usage)
  })

  it('defaults to an empty map when the payload omits usage', () => {
    const store = useSchemaStore()
    store.$patch({ schemaData: { ...mockSchemaData, usage: undefined } })
    expect(store.usage).toEqual({})
  })
})
