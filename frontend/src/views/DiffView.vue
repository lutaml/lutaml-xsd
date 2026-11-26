<template>
  <div class="diff-view">
    <div class="diff-header">
      <div>
        <h1>Schema changes</h1>
        <p class="diff-subtitle">
          Component-level diff against the previous package version
        </p>
      </div>
      <div class="diff-summary">
        <span
          v-for="group in groups"
          :key="group.category"
          class="diff-summary-chip"
          :class="`chip-${group.category}`"
        >
          {{ group.label }} {{ group.changes.length }}
        </span>
      </div>
    </div>

    <p v-if="groups.length === 0" class="diff-empty">
      No schema diff embedded in this package. Regenerate with
      <code>lutaml-xsd spa NEW.lxr --diff OLD.lxr</code>.
    </p>

    <section
      v-for="group in groups"
      :key="group.category"
      class="diff-group"
      :aria-label="`${group.label} changes`"
    >
      <h2 class="diff-group-title">{{ group.label }}</h2>
      <div v-for="change in group.changes" :key="changeKey(change)" class="change-row card">
        <div class="change-head">
          <span :class="['badge', `badge-${change.kind}`]">{{ change.kind }}</span>
          <button
            v-if="findComponent(change.local_name)"
            class="change-name"
            @click="openChange(change)"
          >
            {{ change.local_name }}
          </button>
          <span v-else class="change-name static">{{ change.local_name }}</span>
          <span v-if="change.renamed_from" class="change-renamed">
            ← {{ shortIdentity(change.renamed_from) }}
          </span>
        </div>
        <ul v-if="change.modifications && change.modifications.length" class="change-mods">
          <li v-for="(mod, i) in change.modifications" :key="`${changeKey(change)}-${i}`">
            <span class="mod-aspect">{{ mod.aspect }}</span>
            <span v-if="mod.old" class="mod-old">{{ mod.old }}</span>
            <span v-if="mod.old" class="mod-arrow">→</span>
            <span class="mod-new">{{ mod.new ?? '(none)' }}</span>
          </li>
        </ul>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useSchemaStore } from '@/stores/schemaStore'
import { useUiStore } from '@/stores/uiStore'
import type { DiffChange } from '@/types'

const schemaStore = useSchemaStore()
const uiStore = useUiStore()

const CATEGORY_LABELS: Record<string, string> = {
  added: 'Added',
  removed: 'Removed',
  modified: 'Modified',
  renamed: 'Renamed',
  moved_namespace: 'Moved namespace',
}

interface Group {
  category: string
  label: string
  changes: DiffChange[]
}

const groups = computed<Group[]>(() => {
  const changes = schemaStore.diff?.changes ?? []
  const byCategory = new Map<string, DiffChange[]>()
  changes.forEach(c => {
    const list = byCategory.get(c.category) ?? []
    list.push(c)
    byCategory.set(c.category, list)
  })
  const order = ['modified', 'renamed', 'moved_namespace', 'added', 'removed']
  return order
    .filter(category => byCategory.has(category))
    .map(category => ({
      category,
      label: CATEGORY_LABELS[category] ?? category,
      changes: byCategory.get(category)!,
    }))
})

function changeKey(change: DiffChange): string {
  return `${change.category}-${change.namespace}-${change.local_name}`
}

function shortIdentity(identity: string): string {
  return identity.replace(/^\{[^}]*\}/, '')
}

function openChange(change: DiffChange) {
  const target = findComponent(change.local_name)
  if (!target) return
  schemaStore.selectSchema(target.schemaId)
  schemaStore.selectType(target.typeId)
  uiStore.openDetailPanel()
}

interface ComponentTarget {
  schemaId: string
  typeId: string
}

function findComponent(name: string): ComponentTarget | null {
  if (!name) return null
  for (const schema of schemaStore.schemas) {
    const complex = schema.complex_types?.find(t => t.name === name)
    if (complex) return { schemaId: schema.id, typeId: complex.id }
    const simple = schema.simple_types?.find(t => t.name === name)
    if (simple) return { schemaId: schema.id, typeId: simple.id }
  }
  return null
}
</script>

<style scoped>
.diff-view {
  padding: 1.5rem 2rem;
  max-width: 60rem;
  margin: 0 auto;
}

.diff-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 1rem;
  margin-bottom: 1.25rem;
  flex-wrap: wrap;
}

.diff-header h1 {
  margin: 0 0 0.25rem;
  font-size: 1.4rem;
}

.diff-subtitle {
  margin: 0;
  color: var(--text-secondary);
  font-size: 0.85rem;
}

.diff-summary {
  display: flex;
  gap: 0.4rem;
  flex-wrap: wrap;
}

.diff-summary-chip {
  font-size: 0.75rem;
  padding: 0.15rem 0.55rem;
  border-radius: 999px;
  background: var(--bg-secondary);
  color: var(--text-secondary);
}

.chip-added {
  background: var(--color-green-alpha, var(--bg-secondary));
}

.chip-removed {
  background: var(--color-red-alpha, var(--bg-secondary));
}

.diff-empty {
  color: var(--text-secondary);
  padding: 2rem 0;
  text-align: center;
}

.diff-group {
  margin-bottom: 1.5rem;
}

.diff-group-title {
  font-size: 1.05rem;
  margin: 0 0 0.6rem;
}

.change-row {
  padding: 0.55rem 0.8rem;
  margin-bottom: 0.45rem;
}

.change-head {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.change-name {
  background: none;
  border: none;
  color: var(--color-accent-text);
  cursor: pointer;
  font-weight: 600;
  font-size: 0.92rem;
  padding: 0;
}

.change-name:hover {
  text-decoration: underline;
}

.change-name.static {
  cursor: default;
  color: var(--text-primary);
}

.change-renamed {
  color: var(--text-secondary);
  font-size: 0.82rem;
}

.badge {
  font-size: 0.68rem;
  padding: 0.1rem 0.4rem;
  border-radius: 4px;
  background: var(--bg-secondary);
  color: var(--text-secondary);
}

.change-mods {
  list-style: none;
  margin: 0.35rem 0 0;
  padding: 0.25rem 0 0 1.2rem;
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.change-mods li {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.84rem;
}

.mod-aspect {
  color: var(--text-secondary);
  min-width: 6rem;
}

.mod-old {
  color: var(--color-red);
  text-decoration: line-through;
}

.mod-arrow {
  color: var(--text-secondary);
}

.mod-new {
  color: var(--color-derivation-text, var(--text-primary));
}
</style>
