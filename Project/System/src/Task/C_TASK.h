//
//  C_TASK.h
//  pop'n rhythmin
//
//  Base class of the engine's task/scene framework. Every gameplay and animated
//  screen (MainTask, TitleTask, MusicSelTask, ResultTask, SugorokuMainTask, ...)
//  derives from C_TASK. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (Obj-C type-encoding: "{C_TASK=^^?^{C_TASK}^{C_TASK}i...}").
//
//  Tasks live in a single PRIORITY-SORTED doubly-linked list (the scheduler,
//  head @ DAT_00188468). Each frame the manager walks the list in priority order
//  and updates/draws every task. setPriority() repositions a task in that list.
//

#pragma once

class C_TASK {
public:
    C_TASK();                       // Ghidra: FUN_0002af58 (via base FUN_00027ea8)
    virtual ~C_TASK();

    // Per-frame hooks dispatched by the scheduler (vtable @ PTR_FUN_0002b02c).
    virtual void update();
    virtual void draw();

    // Re-insert this task into the scheduler list at `priority`, keeping the
    // list sorted (unlink from current slot, walk from the head to the first
    // node with priority >= p, insert before it). Ghidra: FUN_00027f08.
    void setPriority(int priority);

    int priority() const { return m_priority; }

protected:
    // Intrusive list links + priority (offsets verified: +0x4 / +0x8 / +0xc).
    C_TASK *m_prev;      // +0x04
    C_TASK *m_next;      // +0x08
    int m_priority;      // +0x0c

    // Scene-tree links + metadata (from the type-encoding; exact roles partial).
    C_TASK *m_parent;    // +0x10
    C_TASK *m_link1;     // +0x14
    C_TASK *m_link2;     // +0x18
    C_TASK *m_link3;     // +0x1c
    char *m_name;        // +0x20
    bool m_active;       // +0x24

    // Transform initialized by the ctor (position / scale; words 0xa..0x12).
    // TODO: name the individual transform fields.
    float m_transform[10];  // +0x28..
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
