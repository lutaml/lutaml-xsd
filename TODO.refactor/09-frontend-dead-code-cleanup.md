# Frontend dead code cleanup in TypeOverview.vue

## Problem
The `hasBase` computed already returns `false` for element types, making the
element guard in `baseValue` unreachable dead code:
```typescript
if (props.type.type === 'element') return ''  // unreachable
```

Similarly, `navigateToBase` has a dead early return:
```typescript
if (props.type.type === 'element') return  // unreachable since hasBase is false
```

## Solution
- Remove dead element guards from `baseValue` and `navigateToBase`
- Since `hasBase` handles element/group/attribute_group, the remaining code
  in `baseValue` only needs to handle complex/simple types

## Files affected
- `frontend/src/components/TypeOverview.vue`

## Acceptance criteria
- [ ] No unreachable code paths in computed properties
- [ ] Frontend builds without errors
