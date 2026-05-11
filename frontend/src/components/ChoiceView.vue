<template>
  <div class="choice-view">
    <div class="choice-header">
      <span class="choice-label">Choices</span>
      <span v-if="choice.occurs" class="choice-occurs">{{ formatOccurs(choice.occurs) }}</span>
    </div>
    <p v-if="choice.documentation" class="choice-documentation">{{ choice.documentation }}</p>

    <!-- Loop elements -->
    <div v-if="choice.elements && choice.elements.length > 0" class="choice-inputs">
      <ul v-for="el in choice.elements">
        <li>{{ el.reference ? navigateToRef(el.reference) : el.name }}</li>
      </ul>
    </div>

    <!-- Loop groups -->
    <div v-if="choice.groups && choice.groups.length > 0">
      <ul v-for="el in choice.groups">
        <li>{{ el.ref ? navigateToRef(el.ref) : el.name }}</li>
      </ul>
    </div>

    <!-- Loop nested choices -->
    <div v-if="choice.choices && choice.choices.length > 0">
      Choices:!!!
      <div v-for="(nestedChoice, ncIdx) in choice.choices" :key="`nc-${ncIdx}`" class="nested-choice-block">
        nestedChoice: {{ nestedChoice }}
        <ChoiceView :choice="nestedChoice" />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { ChoiceElement } from '@/types'
// import GroupTreeItem from './GroupTreeItem.vue'
import { useSchemaStore } from '@/stores/schemaStore'
import { useUiStore } from '@/stores/uiStore'

defineProps<{
  choice: ChoiceElement
}>()

const schemaStore = useSchemaStore()
const uiStore = useUiStore()

function navigateToRef(ref: string) {
  const found = schemaStore.getTypeByName(ref)
  if (found) {
    schemaStore.selectSchema(found.schema.id)
    schemaStore.selectType(found.data.id)
    uiStore.setPanelTab('overview')
    uiStore.openDetailPanel()
  }
}

function formatOccurs(occurs?: { min: number; max?: number | 'unbounded' }): string {
  if (!occurs) return '[1..1]'
  if (occurs.max === undefined || occurs.max === 'unbounded') {
    return occurs.min === 0 ? '[0..*]' : `[${occurs.min}..*]`
  }
  if (occurs.min === occurs.max) return `[${occurs.min}..${occurs.max}]`
  return `[${occurs.min}..${occurs.max}]`
}

// function inputType(occurs?: { min: number; max?: number | 'unbounded' }): string {
//   if (!occurs) return 'radio'
//   if (occurs.min > 1 || occurs.max === undefined || occurs.max === 'unbounded') {
//     return 'checkbox'
//   }
//   return 'radio'
// }
</script>

<style scoped>
.choice-view {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
}

.choice-header {
  display: flex;
  align-items: center;
  gap: var(--space-2);
}

.choice-label {
  font-family: var(--font-mono);
  font-weight: 600;
  color: var(--color-primary);
  font-size: var(--text-sm);
}

.choice-occurs {
  font-size: var(--text-xs);
  color: var(--text-muted);
  font-family: var(--font-mono);
}

.choice-documentation {
  font-size: var(--text-sm);
  color: var(--text-secondary);
  line-height: var(--leading-relaxed);
  margin: 0;
}

.choice-elements,
.choice-groups,
.choice-sequences,
.choice-nested {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}

.subsection-title {
  font-size: var(--text-xs);
  font-weight: 600;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin: 0;
}

.sequence-block {
  background: var(--bg-primary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-sm);
  padding: var(--space-3);
}

.sequence-header {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  margin-bottom: var(--space-2);
}

.sequence-label {
  font-family: var(--font-mono);
  font-size: var(--text-xs);
  color: var(--text-secondary);
}

.sequence-elements {
  margin-top: var(--space-2);
}

.nested-choice-block {
  background: var(--bg-primary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-sm);
  padding: var(--space-3);
  margin-top: var(--space-2);
}

.type-link {
  color: var(--color-primary);
  cursor: pointer;
}

.type-link:hover {
  text-decoration: underline;
}

/* Smaller table variant */
.table-sm {
  font-size: var(--text-xs);
}

.table-sm th,
.table-sm td {
  padding: var(--space-1) var(--space-2);
}

.table-sm .font-mono {
  font-size: var(--text-xs);
}
</style>
