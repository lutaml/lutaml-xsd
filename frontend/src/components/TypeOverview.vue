<template>
  <div class="type-overview">
    <!-- Type Badge, Base, Properties -->
    <div class="overview-section">
      <div class="badge-row">
        <span :class="['badge', `badge-${type.type}`]">
          {{ type.type === 'complex' ? 'Complex Type' : type.type === 'simple' ? 'Simple Type' : type.type === 'element' ? 'Element' : type.type === 'group' ? 'Group' : type.type === 'attribute_group' ? 'Attribute Group' : 'Attribute' }}
        </span>
        <span v-if="isAbstract" class="badge badge-abstract">abstract</span>
        <span v-if="isMixed" class="badge badge-mixed">mixed</span>
        <span v-if="isNillable" class="badge badge-mixed">nillable</span>
        <span v-if="isDeprecated" class="badge badge-deprecated">deprecated</span>
      </div>
      <p v-if="hasBase" class="base-type">
        <span class="base-label">Base:</span>
        <a href="#" @click.prevent="navigateToBase">{{ baseValue }}</a>
      </p>
      <p v-if="substitutionGroup" class="base-type">
        <span class="base-label">Substitution group:</span>
        <a href="#" @click.prevent="navigateToRef(substitutionGroup)">{{ substitutionGroup }}</a>
      </p>
      <p v-if="defaultValue" class="base-type">
        <span class="base-label">Default:</span> <code>{{ defaultValue }}</code>
      </p>
      <p v-if="fixedValue" class="base-type">
        <span class="base-label">Fixed:</span> <code>{{ fixedValue }}</code>
      </p>
    </div>

    <!-- Documentation -->
    <div v-if="type.data.documentation" class="overview-section">
      <h3 class="section-title">Documentation</h3>
      <p class="documentation">{{ type.data.documentation }}</p>
    </div>

    <!-- Restriction Facets (simple types) -->
    <div v-if="restrictionFacets.length > 0" class="overview-section">
      <h3 class="section-title">Restriction</h3>
      <table class="table">
        <thead>
          <tr>
            <th>Facet</th>
            <th>Value</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="facet in restrictionFacets" :key="facet.type">
            <td class="font-mono">{{ facet.type }}</td>
            <td>{{ formatFacetValue(facet) }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Union/List (simple types) -->
    <div v-if="unionMembers.length > 0" class="overview-section">
      <h3 class="section-title">Union Members</h3>
      <div class="tag-list">
        <span v-for="member in unionMembers" :key="member" class="tag">{{ member }}</span>
      </div>
    </div>
    <div v-if="listType" class="overview-section">
      <h3 class="section-title">List Item Type</h3>
      <p class="font-mono">{{ listType }}</p>
    </div>

    <!-- Elements Table -->
    <div v-if="elements.length > 0" class="overview-section">
      <h3 class="section-title">Elements</h3>
      <table class="table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Type</th>
            <th>Occurs</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="el in elements" :key="el.name">
            <td class="font-mono">{{ el.name }}</td>
            <td>
              <span v-if="el.reference" class="type-link" @click="navigateToRef(el.reference)">
                {{ el.type || el.reference }}
              </span>
              <span v-else>{{ el.type || 'xs:anyType' }}</span>
            </td>
            <td class="text-muted">{{ formatOccurs(el.occurs) }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Attributes Table -->
    <div v-if="attributes.length > 0" class="overview-section">
      <h3 class="section-title">Attributes</h3>
      <table class="table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Type</th>
            <th>Use</th>
            <th>Default</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="attr in attributes" :key="attr.name">
            <td class="font-mono">{{ attr.name }}</td>
            <td>{{ attr.type || 'xs:string' }}</td>
            <td>
              <span v-if="attr.use === 'required'" class="badge badge-attribute">required</span>
              <span v-else-if="attr.use === 'optional'" class="text-muted">optional</span>
              <span v-else-if="attr.use === 'prohibited'" class="text-muted">prohibited</span>
            </td>
            <td>
              <code v-if="attr.fixed">fixed: {{ attr.fixed }}</code>
              <code v-else-if="attr.default">{{ attr.default }}</code>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Group References -->
    <div v-if="groupRefs.length > 0" class="overview-section">
      <h3 class="section-title">Groups</h3>
      <div class="tag-list">
        <span v-for="g in groupRefs" :key="g.ref" class="tag type-link" @click="navigateToRef(g.ref)">{{ g.ref }}</span>
      </div>
    </div>

    <!-- Attribute Group References -->
    <div v-if="attributeGroupRefs.length > 0" class="overview-section">
      <h3 class="section-title">Attribute Groups</h3>
      <div class="tag-list">
        <span v-for="ag in attributeGroupRefs" :key="ag.ref" class="tag type-link" @click="navigateToRef(ag.ref)">{{ ag.ref }}</span>
      </div>
    </div>

    <!-- Used By -->
    <div v-if="usedByRefs.length > 0" class="overview-section">
      <h3 class="section-title">Used By</h3>
      <div class="tag-list">
        <span v-for="ref in usedByRefs" :key="ref.name" class="tag type-link" @click="navigateToRef(ref.name)">{{ ref.name }}</span>
      </div>
    </div>

    <!-- XML Instance Example -->
    <div v-if="xmlExample" class="overview-section">
      <h3 class="section-title">XML Instance</h3>
      <pre class="xml-example"><code>{{ xmlExample }}</code></pre>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { ComplexType, SimpleType, SchemaElement, TypeElement, TypeAttribute, GroupRef, AttributeGroupRef, UsedByRef, AttributeGroup } from '@/types'
import { useSchemaStore } from '@/stores/schemaStore'
import { useUiStore } from '@/stores/uiStore'

type TypeData = {
  type: 'complex' | 'simple' | 'element' | 'group' | 'attribute_group' | 'attribute'
  data: ComplexType | SimpleType | SchemaElement
  schema: { id: string; name: string; prefix?: string }
}

const props = defineProps<{ type: TypeData }>()

const schemaStore = useSchemaStore()
const uiStore = useUiStore()

const hasBase = computed(() => {
  if (props.type.type === 'element' || props.type.type === 'group' || props.type.type === 'attribute_group') return false
  return !!(props.type.data as ComplexType | SimpleType).base
})

const baseValue = computed(() => {
  if (props.type.type === 'element') return ''
  return (props.type.data as ComplexType | SimpleType).base || ''
})

const isAbstract = computed(() => {
  return !!(props.type.data as any).abstract
})

const isMixed = computed(() => {
  return !!(props.type.data as any).mixed
})

const isNillable = computed(() => {
  return !!(props.type.data as any).nillable
})

const isDeprecated = computed(() => {
  return !!(props.type.data as any).deprecated
})

const substitutionGroup = computed(() => {
  return (props.type.data as any).substitution_group || ''
})

const defaultValue = computed(() => {
  return (props.type.data as any).default || ''
})

const fixedValue = computed(() => {
  return (props.type.data as any).fixed || ''
})

const elements = computed<TypeElement[]>(() => {
  if (props.type.type === 'complex' || props.type.type === 'group') {
    return (props.type.data as ComplexType).elements || []
  }
  return []
})

const attributes = computed<TypeAttribute[]>(() => {
  if (props.type.type === 'complex') {
    return (props.type.data as ComplexType).attributes || []
  }
  if (props.type.type === 'attribute_group') {
    return (props.type.data as AttributeGroup).attributes || []
  }
  return []
})

const restrictionFacets = computed(() => {
  if (props.type.type !== 'simple') return []
  const restriction = (props.type.data as SimpleType).restriction
  if (!restriction) return []
  const facets: { type: string; values?: string[]; value?: string | number }[] = []
  if (restriction.enumeration) facets.push({ type: 'enumeration', values: restriction.enumeration.map(e => e.value) })
  if (restriction.pattern) facets.push({ type: 'pattern', value: restriction.pattern })
  if (restriction.min_length !== undefined) facets.push({ type: 'minLength', value: restriction.min_length })
  if (restriction.max_length !== undefined) facets.push({ type: 'maxLength', value: restriction.max_length })
  if (restriction.min_inclusive !== undefined) facets.push({ type: 'minInclusive', value: restriction.min_inclusive })
  if (restriction.max_inclusive !== undefined) facets.push({ type: 'maxInclusive', value: restriction.max_inclusive })
  if (restriction.length !== undefined) facets.push({ type: 'length', value: restriction.length })
  return facets
})

const unionMembers = computed(() => {
  if (props.type.type !== 'simple') return []
  return (props.type.data as SimpleType).union || []
})

const listType = computed(() => {
  if (props.type.type !== 'simple') return ''
  return (props.type.data as SimpleType).list || ''
})

const groupRefs = computed<GroupRef[]>(() => {
  if (props.type.type !== 'complex') return []
  return (props.type.data as ComplexType).groups || []
})

const attributeGroupRefs = computed<AttributeGroupRef[]>(() => {
  if (props.type.type !== 'complex') return []
  return (props.type.data as ComplexType).attribute_groups || []
})

const usedByRefs = computed<UsedByRef[]>(() => {
  return ((props.type.data as any).used_by || [])
})

const xmlExample = computed<string | null>(() => {
  if (!props.type.schema.prefix) return null

  const prefix = props.type.schema.prefix
  const name = props.type.data.name

  if (props.type.type === 'element') {
    return `<${prefix}:${name}>\n  <!-- content -->\n</${prefix}:${name}>`
  }

  let content = ''
  elements.value.forEach(el => {
    const elPrefix = el.type?.includes(':') ? el.type.split(':')[0] : prefix
    const elName = el.type?.includes(':') ? el.type.split(':')[1] : (el.reference || 'value')
    const occurs = el.occurs
    if (occurs?.min === 0) {
      content += `  <${elPrefix}:${elName}>?</${elPrefix}:${elName}>\n`
    } else {
      content += `  <${elPrefix}:${elName}>value</${elPrefix}:${elName}>\n`
    }
  })

  return `<${prefix}:${name}${props.type.type === 'complex' ? ' gml:id="..."' : ''}>\n${content}</${prefix}:${name}>`
})

function formatOccurs(occurs?: { min: number; max?: number | 'unbounded' }): string {
  if (!occurs) return '[1..1]'
  if (occurs.max === undefined || occurs.max === 'unbounded') {
    return occurs.min === 0 ? '[0..*]' : `[${occurs.min}..*]`
  }
  if (occurs.min === occurs.max) return `[${occurs.min}..${occurs.max}]`
  return `[${occurs.min}..${occurs.max}]`
}

function formatFacetValue(facet: { type: string; values?: string[]; value?: string | number }): string {
  if (facet.values) return facet.values.join(', ')
  return String(facet.value ?? '')
}

function navigateToBase() {
  if (props.type.type === 'element') return
  const base = (props.type.data as ComplexType | SimpleType).base
  if (!base) return

  const found = schemaStore.getTypeByName(base)
  if (found) {
    schemaStore.selectSchema(found.schema.id)
    schemaStore.selectType(found.data.id)
  }
}

function navigateToRef(ref: string) {
  const found = schemaStore.getTypeByName(ref)
  if (found) {
    schemaStore.selectSchema(found.schema.id)
    schemaStore.selectType(found.data.id)
    uiStore.setPanelTab('overview')
    uiStore.openDetailPanel()
  }
}
</script>

<style scoped>
.type-overview {
  display: flex;
  flex-direction: column;
  gap: var(--space-5);
}

.overview-section {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}

.badge-row {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}

.base-type {
  font-size: var(--text-sm);
  color: var(--text-secondary);
}

.base-label {
  color: var(--text-muted);
  margin-right: var(--space-1);
}

.type-link {
  color: var(--color-primary);
  cursor: pointer;
}

.type-link:hover {
  text-decoration: underline;
}

.section-title {
  font-size: var(--text-xs);
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-muted);
}

.documentation {
  font-size: var(--text-sm);
  color: var(--text-secondary);
  line-height: var(--leading-relaxed);
}

.xml-example {
  background: var(--bg-secondary);
  padding: var(--space-4);
  border-radius: var(--radius-md);
  overflow-x: auto;
  font-size: var(--text-sm);
}

.tag-list {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-1);
}

.tag {
  font-size: var(--text-xs);
  padding: 2px 8px;
  border-radius: var(--radius-sm);
  background: var(--bg-secondary);
  color: var(--text-secondary);
}

.badge-abstract {
  background: rgba(168, 85, 247, 0.15);
  color: #a855f7;
}

.badge-mixed {
  background: rgba(245, 158, 11, 0.15);
  color: #f59e0b;
}

.badge-deprecated {
  background: rgba(239, 68, 68, 0.15);
  color: #ef4444;
}

code {
  font-size: var(--text-xs);
  background: var(--bg-secondary);
  padding: 1px 4px;
  border-radius: var(--radius-sm);
}
</style>
