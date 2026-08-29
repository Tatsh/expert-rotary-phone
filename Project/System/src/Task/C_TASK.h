/**
 * @file
 * @brief The base class of the engine's task and scene framework.
 *
 * Every gameplay and animated screen (MainTask,
 * TitleTask, AcMainTask, PlayResultTask, AcViewerTask, ...) derives from C_TASK. Reconstructed
 * from Ghidra project rb420, program PopnRhythmin (Objective-C type-encoding:
 * "{C_TASK=^^?^{C_TASK}^{C_TASK}i...}").
 *
 * Tasks live in a single priority-sorted doubly-linked list (the scheduler, head @
 * DAT_00188468). Each frame the manager walks the list in priority order and updates and draws
 * every task. setPriority() repositions a task in that list.
 */

#pragma once

namespace ne {

/**
 * @brief Base class of every engine task: a node in the scheduler's priority-sorted list that
 * receives per-frame update() and draw() callbacks.
 */
class C_TASK {
public:
    /**
     * @brief Construct a task at the default priority and self-link it into the scheduler.
     * @ghidraAddress 0x27ea8
     */
    C_TASK();
    /**
     * @brief Unlink the task from the scheduler list.
     */
    virtual ~C_TASK();

    /**
     * @brief Per-frame logic hook dispatched by the scheduler; concrete tasks override it.
     *
     * Each concrete subclass — for example BootLogoTask (constructor FUN_0002af58, vtable
     * PTR_FUN_0002b02c) — appends its own fields from +0x28 on.
     * @param deltaMs Milliseconds elapsed since the previous scheduler tick.
     */
    virtual void update(int deltaMs);
    /**
     * @brief Per-frame render hook dispatched by the scheduler; concrete tasks override it.
     */
    virtual void draw();

    /**
     * @brief Re-insert this task into the scheduler list at @p priority, keeping the list sorted.
     *
     * Unlinks the task from its current slot, walks from the head to the first node whose
     * priority is greater than or equal to @p priority, and inserts before it.
     * @param priority The new scheduling priority; lower values run earlier.
     * @ghidraAddress 0x27f08
     */
    void setPriority(int priority);

    /**
     * @brief This task's scheduling priority.
     * @return The priority; lower values run earlier.
     */
    int priority() const {
        return m_priority;
    }

    /**
     * @brief Mark this task for destruction on the next scheduler pass.
     */
    void kill() {
        m_killed = true;
    }

    /**
     * @brief The scheduler tick: walk the priority list in order, update() every live task and
     * destroy (reap) any task whose active flag is clear.
     * @param deltaMs Milliseconds elapsed since the previous tick.
     * @ghidraAddress 0x27f40
     */
    static void updateAll(int deltaMs);

private:
    /**
     * @brief The scheduler's sentinel head (Ghidra: DAT_00188468) — a self-linked node with max
     * priority that bounds the circular priority list.
     * @return The sentinel node.
     */
    static C_TASK &scheduler();

protected:
    C_TASK *m_prev; /**< +0x04 Previous node in the scheduler's priority list. */
    C_TASK *m_next; /**< +0x08 Next node in the scheduler's priority list. */
    int m_priority; /**< +0x0c Scheduling priority; lower values run earlier. */

    C_TASK *m_parent; /**< +0x10 Owning task in the scene tree. */
    C_TASK *m_link1;  /**< +0x14 Scene-tree link (role partial). */
    C_TASK *m_link2;  /**< +0x18 Scene-tree link (role partial). */
    C_TASK *m_link3;  /**< +0x1c Scene-tree link (role partial). */
    char *m_name;     /**< +0x20 Debug name. */
    bool m_killed;    /**< +0x24 Set to reap this task on the next scheduler pass. */

    // The position/scale transform at +0x28..+0x48 is NOT part of the base node — it is added and
    // initialised by the drawable-task subclass (Ghidra: FUN_0002af58, vtable PTR_FUN_0002b02c).
    // The base constructor (FUN_00027ea8) only sets the vtable, self-links, priority (9), name and
    // killed flag.
};

} // namespace ne
