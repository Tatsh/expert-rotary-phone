//
//  C_TASK.cpp
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#include "C_TASK.h"

// Head/sentinel of the priority-sorted scheduler list (Ghidra: DAT_00188468).
// Nodes are ordered by ascending priority; the frame loop walks from here.
extern C_TASK *g_taskListHead;

// Ghidra: FUN_0002af58 (allocates via FUN_00027ea8, sets vtable, zeroes fields
// + the transform words 0xa..0x12).
C_TASK::C_TASK()
    : m_prev(nullptr), m_next(nullptr), m_priority(0),
      m_parent(nullptr), m_link1(nullptr), m_link2(nullptr), m_link3(nullptr),
      m_name(nullptr), m_active(false) {
    for (auto &f : m_transform) {
        f = 0.0f;
    }
}

C_TASK::~C_TASK() = default;

void C_TASK::update() {}
void C_TASK::draw() {}

// Ghidra: FUN_00027f08 — reposition this task in the priority-sorted list.
void C_TASK::setPriority(int priority) {
    // Unlink from the current slot.
    m_next->m_prev = m_prev;
    m_prev->m_next = m_next;

    // Walk from the head to the first node whose priority >= `priority`.
    C_TASK *prev = g_taskListHead;
    C_TASK *node = prev->m_next;
    while (node->m_priority < priority) {
        prev = node;
        node = node->m_next;
    }

    // Insert before `node`, keeping the list sorted.
    m_next = node;
    m_prev = prev;
    prev->m_next = this;
    m_next->m_prev = this;
    m_priority = priority;
}
