import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { RngData, Grammar, Define } from '@/types'

export const useGrammarStore = defineStore('grammar', () => {
  const rngData = ref<RngData | null>(null)
  const selectedGrammarId = ref<string | null>(null)
  const expandedDefines = ref<Set<string>>(new Set())

  const grammars = computed(() => rngData.value?.grammars ?? [])
  const metadata = computed(() => rngData.value?.metadata)

  const selectedGrammar = computed(() =>
    grammars.value.find(g => g.id === selectedGrammarId.value) ?? null
  )

  const totalDefines = computed(() =>
    grammars.value.reduce((acc, g) =>
      acc + g.define_groups.reduce((acc2, grp) => acc2 + grp.defines.length, 0), 0)
  )

  function loadFromWindow() {
    if (typeof window !== 'undefined' && window.RNG_DATA) {
      rngData.value = window.RNG_DATA
      if (grammars.value.length > 0) {
        selectedGrammarId.value = grammars.value[0].id
      }
    }
  }

  function selectGrammar(id: string) {
    selectedGrammarId.value = id
    expandedDefines.value.clear()
  }

  function toggleDefine(name: string) {
    if (expandedDefines.value.has(name)) {
      expandedDefines.value.delete(name)
    } else {
      expandedDefines.value.add(name)
    }
  }

  function isDefineExpanded(name: string): boolean {
    return expandedDefines.value.has(name)
  }

  return {
    rngData,
    selectedGrammarId,
    expandedDefines,
    grammars,
    metadata,
    selectedGrammar,
    totalDefines,
    loadFromWindow,
    selectGrammar,
    toggleDefine,
    isDefineExpanded
  }
})
