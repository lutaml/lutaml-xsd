<template>
  <div class="graphs-view">
    <div class="graphs-header">
      <div>
        <h1>Model graphs</h1>
        <p class="graphs-subtitle">
          Derivation chains and usage navigation across the package
        </p>
      </div>
      <div class="graphs-tabs" role="tablist" aria-label="Graph views">
        <button
          class="tab-btn"
          :class="{ active: activeTab === 'usage' }"
          role="tab"
          :aria-selected="activeTab === 'usage'"
          @click="activeTab = 'usage'"
        >
          Usage
          <span class="tab-count">{{ rankedTypes.length }}</span>
        </button>
        <button
          class="tab-btn"
          :class="{ active: activeTab === 'derivation' }"
          role="tab"
          :aria-selected="activeTab === 'derivation'"
          @click="activeTab = 'derivation'"
        >
          Derivation
          <span class="tab-count">{{ chainTypes.length }}</span>
        </button>
      </div>
    </div>

    <!-- Usage tab: types ranked by how many components reference them -->
    <div v-if="activeTab === 'usage'" class="graphs-content">
      <p v-if="rankedTypes.length === 0" class="graphs-empty">
        No usage data in this package.
      </p>
      <div
        v-for="entry in rankedTypes"
        :key="entry.name"
        class="usage-row card"
      >
        <button
          class="usage-toggle"
          :aria-expanded="expanded === entry.name"
          @click="toggleExpanded(entry.name)"
        >
          <span class="usage-caret">{{ expanded === entry.name ? '▾' : '▸' }}</span>
        </button>
        <button class="usage-type-link" @click="openType(entry.name, entry.refs[0])">
          {{ entry.name }}
        </button>
        <span class="usage-count" :title="`${entry.refs.length} referencing components`">
          {{ entry.refs.length }}
        </span>
        <div v-if="expanded === entry.name" class="usage-refs">
          <button
            v-for="(ref, i) in entry.refs"
            :key="`${ref.by}-${ref.name}-${ref.schema}-${i}`"
            class="usage-ref"
            @click="openType(ref.name, ref)"
          >
            <span :class="['badge', `badge-${ref.by}`]">{{ ref.by }}</span>
            <span class="usage-ref-name">{{ ref.name }}</span>
            <span class="usage-ref-schema">{{ ref.schema }}</span>
          </button>
        </div>
      </div>
    </div>

    <!-- Derivation tab: every type with a chain to its root -->
    <div v-else class="graphs-content">
      <p v-if="chainTypes.length === 0" class="graphs-empty">
        No derivation chains in this package.
      </p>
      <div
        v-for="entry in chainTypes"
        :key="entry.name"
        class="chain-row card"
      >
        <button class="usage-type-link" @click="openType(entry.name, entry.ref)">
          {{ entry.name }}
        </button>
        <div class="chain-steps" aria-label="Derivation chain">
          <template v-for="(hop, i) in entry.chain" :key="hop">
            <span v-if="i > 0" class="chain-arrow">→</span>
            <button class="chain-hop" @click="openType(hopName(hop), hopRef(hop))">
              {{ hopName(hop) }}
            </button>
          </template>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useSchemaStore } from '@/stores/schemaStore'
import { useUiStore } from '@/stores/uiStore'
import type { UsageRef } from '@/types'

const schemaStore = useSchemaStore()
const uiStore = useUiStore()

const activeTab = ref<'usage' | 'derivation'>('usage')
const expanded = ref<string | null>(null)

const usage = computed(() => schemaStore.usage)

interface RankedEntry {
  name: string
  refs: UsageRef[]
}

const rankedTypes = computed<RankedEntry[]>(() =>
  Object.entries(usage.value)
    .map(([name, refs]) => ({ name, refs }))
    .filter(e => e.refs.length > 0)
    .sort((a, b) => b.refs.length - a.refs.length || a.name.localeCompare(b.name))
)

interface ChainEntry {
  name: string
  chain: string[]
  ref: UsageRef
}

const chainTypes = computed<ChainEntry[]>(() => {
  const entries: ChainEntry[] = []
  Object.entries(schemaStore.hierarchy).forEach(([name, h]) => {
    if (!h.chain || h.chain.length === 0) return
    const ref = usage.value[name]?.[0] ?? { by: 'derivation', name, schema: '' }
    entries.push({ name, chain: h.chain, ref })
  })
  return entries.sort((a, b) => a.name.localeCompare(b.name))
})

function toggleExpanded(name: string) {
  expanded.value = expanded.value === name ? null : name
}

// The hop text is "Child --> Parent"; hops navigate to the parent side.
function hopName(hop: string): string {
  return hop.split('-->').pop()?.trim() ?? hop
}

function hopRef(hop: string): UsageRef {
  const name = hopName(hop)
  return usage.value[name]?.[0] ?? { by: 'derivation', name, schema: '' }
}

function openType(name: string, ref: UsageRef | undefined) {
  if (!name) return
  const target = findComponent(name, ref?.schema)
  if (!target) return
  schemaStore.selectSchema(target.schemaId)
  schemaStore.selectType(target.typeId)
  uiStore.openDetailPanel()
}

interface ComponentTarget {
  schemaId: string
  typeId: string
}

function findComponent(name: string, schemaHint?: string): ComponentTarget | null {
  const schemas = schemaStore.schemas
  const scoped = schemaHint ? schemas.filter(s => s.name === schemaHint) : schemas
  const pools = scoped.length > 0 ? scoped : schemas
  for (const schema of pools) {
    const complex = schema.complex_types?.find(t => t.name === name)
    if (complex) return { schemaId: schema.id, typeId: complex.id }
    const simple = schema.simple_types?.find(t => t.name === name)
    if (simple) return { schemaId: schema.id, typeId: simple.id }
  }
  return null
}
</script>

<style scoped>
.graphs-view {
  padding: 1.5rem 2rem;
  max-width: 60rem;
  margin: 0 auto;
}

.graphs-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 1rem;
  margin-bottom: 1.25rem;
  flex-wrap: wrap;
}

.graphs-header h1 {
  margin: 0 0 0.25rem;
  font-size: 1.4rem;
}

.graphs-subtitle {
  margin: 0;
  color: var(--color-text-secondary);
  font-size: 0.85rem;
}

.graphs-tabs {
  display: flex;
  gap: 0.5rem;
}

.graphs-empty {
  color: var(--color-text-secondary);
  padding: 2rem 0;
  text-align: center;
}

.usage-row,
.chain-row {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  padding: 0.55rem 0.8rem;
  margin-bottom: 0.45rem;
  flex-wrap: wrap;
}

.usage-toggle {
  background: none;
  border: none;
  cursor: pointer;
  padding: 0 0.15rem;
  color: var(--color-text-secondary);
}

.usage-caret {
  font-size: 0.8rem;
}

.usage-type-link {
  background: none;
  border: none;
  color: var(--color-accent);
  cursor: pointer;
  font-weight: 600;
  font-size: 0.92rem;
  padding: 0;
}

.usage-type-link:hover {
  text-decoration: underline;
}

.usage-count {
  margin-left: auto;
  background: var(--color-accent-alpha);
  color: var(--color-accent);
  border-radius: 999px;
  padding: 0.1rem 0.55rem;
  font-size: 0.78rem;
  font-weight: 600;
}

.usage-refs {
  flex-basis: 100%;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  padding: 0.4rem 0 0.2rem 1.4rem;
}

.usage-ref {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  background: none;
  border: none;
  padding: 0.15rem 0.3rem;
  cursor: pointer;
  text-align: left;
  border-radius: 4px;
}

.usage-ref:hover {
  background: var(--color-bg-secondary);
}

.usage-ref-name {
  font-size: 0.88rem;
}

.usage-ref-schema {
  color: var(--color-text-secondary);
  font-size: 0.78rem;
  margin-left: auto;
}

.badge {
  font-size: 0.68rem;
  padding: 0.1rem 0.4rem;
  border-radius: 4px;
  background: var(--color-bg-secondary);
  color: var(--color-text-secondary);
  text-transform: capitalize;
}

.badge-element {
  background: var(--color-accent-alpha);
  color: var(--color-accent);
}

.badge-derivation {
  background: rgba(46, 125, 50, 0.15);
  color: #2e7d32;
}

.chain-steps {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  flex-wrap: wrap;
}

.chain-arrow {
  color: var(--color-text-secondary);
}

.chain-hop {
  background: none;
  border: none;
  color: var(--color-accent);
  cursor: pointer;
  font-size: 0.88rem;
  padding: 0;
}

.chain-hop:hover {
  text-decoration: underline;
}
</style>
