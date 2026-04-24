<template>
  <!-- Object nodes: skip label, just render children inline -->
  <template v-if="node.type === 'object'">
    <TreeNode
      v-for="(child, i) in node.children"
      :key="i"
      :node="child"
      :depth="depth"
    />
  </template>

  <!-- Non-object nodes: show label row -->
  <li v-else class="tree-node">
    <div class="tree-row" @click="hasChildren && toggle()">
      <span v-if="hasChildren" class="tree-toggle">{{ expanded ? '▼' : '▶' }}</span>
      <span v-else class="tree-spacer"></span>
      <span class="tree-label" :class="`label-${node.type}`">{{ node.label }}</span>
      <span v-if="node.value" class="tree-value">{{ node.value }}</span>
    </div>
    <ul v-if="hasChildren && expanded" class="tree-children">
      <TreeNode
        v-for="(child, i) in node.children"
        :key="i"
        :node="child"
        :depth="depth + 1"
      />
    </ul>
  </li>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import type { TreeNode as TreeNodeType } from '@/types'

const props = defineProps<{
  node: TreeNodeType
  depth: number
}>()

const hasChildren = computed(() => props.node.children.length > 0)
const expanded = ref(props.depth < 3)

function toggle() {
  expanded.value = !expanded.value
}
</script>

<style scoped>
.tree-node {
  list-style: none;
}

.tree-row {
  display: flex;
  align-items: baseline;
  gap: 4px;
  padding: 1px 0;
  cursor: default;
  font-size: 12px;
  line-height: 1.6;
}

.tree-row:hover {
  background: var(--bg-hover);
}

.tree-toggle {
  font-size: 9px;
  color: var(--text-muted);
  width: 12px;
  text-align: center;
  cursor: pointer;
  flex-shrink: 0;
}

.tree-spacer {
  width: 12px;
  flex-shrink: 0;
}

.tree-label {
  font-family: var(--font-mono);
  white-space: nowrap;
}

.label-collection {
  color: var(--badge-element);
  font-weight: 500;
}

.label-scalar {
  color: var(--text-secondary);
}

.label-circular {
  color: var(--text-muted);
  font-style: italic;
}

.tree-value {
  font-family: var(--font-mono);
  font-size: 11px;
  color: var(--text-muted);
  margin-left: 4px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.tree-children {
  padding-left: 16px;
  margin: 0;
  list-style: none;
}
</style>
