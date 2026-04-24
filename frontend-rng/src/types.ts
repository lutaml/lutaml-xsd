export {}

declare global {
  interface Window {
    RNG_DATA: RngData
  }
}

export interface RngData {
  metadata: RngMetadata
  grammars: Grammar[]
}

export interface RngMetadata {
  title?: string
  name?: string
  generated?: string
  generator?: string
  grammar_count?: number
  description?: string
}

export interface Grammar {
  id: string
  name: string
  file_path: string
  start_refs: string[]
  define_groups: DefineGroup[]
  model_tree: TreeNode
}

export interface TreeNode {
  label: string
  type: 'object' | 'collection' | 'scalar' | 'circular'
  value?: string | null
  children: TreeNode[]
}

export interface DefineGroup {
  source: string          // "main" or "include"
  source_href?: string    // the include href, null for main
  defines: Define[]
}

export interface Define {
  name: string
  combine?: string
  content_type: string
  child_elements: string[]
  child_refs: RefEntry[]
  child_attributes: RefEntry[]
  child_values: ValueEntry[]
  child_data: DataEntry[]
  documentation?: string
}

export interface RefEntry {
  name: string
  context?: string  // "optional" | "zeroOrMore" | "oneOrMore" | "choice" | null
}

export interface ValueEntry {
  value: string
  type?: string
  context?: string
}

export interface DataEntry {
  type: string
  context?: string
}
