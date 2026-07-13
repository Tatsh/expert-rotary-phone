//
//  C_TASK.h
//  pop'n rhythmin
//
//  Base class of the engine's task/scene framework. Every gameplay and animated
//  screen (MainTask, TitleTask, AcMainTask, PlayResultTask, AcViewerTask, ...)
//  derives from C_TASK. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (Obj-C type-encoding: "{C_TASK=^^?^{C_TASK}^{C_TASK}i...}").
//
//  Tasks live in a single PRIORITY-SORTED doubly-linked list (the scheduler,
//  head @ DAT_00188468). Each frame the manager walks the list in priority
//  order and updates/draws every task. setPriority() repositions a task in that
//  list.
//

#pragma once

class C_TASK {
public:
    C_TASK(); // Ghidra: base ctor FUN_00027ea8 (vtable PTR_LAB_00027f88)
    virtual ~C_TASK();

    // Per-frame hooks dispatched by the scheduler; concrete tasks override them.
    // (Base vtable @ PTR_LAB_00027f88.) Each concrete subclass — e.g.
    // BootLogoTask (ctor FUN_0002af58, vtable PTR_FUN_0002b02c) — appends its own
    // fields from +0x28 on.
    virtual void update(int deltaMs);
    virtual void draw();

    // Re-insert this task into the scheduler list at `priority`, keeping the
    // list sorted (unlink from current slot, walk from the head to the first
    // node with priority >= p, insert before it). Ghidra: FUN_00027f08.
    void setPriority(int priority);

    int priority() const {
        return m_priority;
    }

    // Mark this task for destruction on the next scheduler pass.
    void kill() {
        m_killed = true;
    }

    // The scheduler tick: walk the priority list in order, update() every live
    // task and destroy (reap) any task whose m_active flag is clear. Ghidra:
    // FUN_00027f40 over the list head @ DAT_00188468.
    static void updateAll(int deltaMs);

private:
    // The scheduler's sentinel head (Ghidra: DAT_00188468) — a self-linked node
    // with max priority that bounds the circular priority list.
    static C_TASK &scheduler();

protected:
    // Intrusive list links + priority (offsets verified: +0x4 / +0x8 / +0xc).
    C_TASK *m_prev; // +0x04
    C_TASK *m_next; // +0x08
    int m_priority; // +0x0c

    // Scene-tree links + metadata (from the type-encoding; exact roles partial).
    C_TASK *m_parent; // +0x10
    C_TASK *m_link1;  // +0x14
    C_TASK *m_link2;  // +0x18
    C_TASK *m_link3;  // +0x1c
    char *m_name;     // +0x20
    bool m_killed;    // +0x24  (0 = alive; set to reap on the next pass)

    // NOTE: the position/scale transform at +0x28..+0x48 is NOT part of the base
    // node — it is added and initialised by the drawable-task subclass (Ghidra:
    // FUN_0002af58, vtable PTR_FUN_0002b02c). The base ctor (FUN_00027ea8) only
    // sets the vtable, self-links, priority (9), name and killed flag.
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
