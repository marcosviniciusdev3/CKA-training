# Evaluation Report: Exercise 22 — PriorityClass

This report evaluates your implementation of **Exercise 22 (PriorityClass)**.

---

## 📊 Summary Score

* **Domain:** Workloads & Scheduling (15% of CKA exam)
* **Status:** **Mastered (10/10)** 

All components of your implementation meet the CKA requirements exactly. The PriorityClasses and Pods are correctly specified, associated, and running in the cluster.

---

## 🔍 Task-by-Task Evaluation

### Task 1: Create `high-priority` PriorityClass
* **Requirement**: PriorityClass named `high-priority`, value `1000`, `preemptionPolicy: PreemptLowerPriority`.
* **Status**: **Passed (100%)**
* **Verification**:
  - Configured correctly in [high-priority.yaml](file:///home/router/Documents/CKA/CKA-Certified-Kubernetes-Administrator/exercises/22-priorityclass/high-priority.yaml).
  - Deployed configuration on the cluster:
    ```bash
    $ kubectl get priorityclass high-priority
    NAME            VALUE   GLOBAL-DEFAULT   AGE    PREEMPTIONPOLICY
    high-priority   1000    false            8m     PreemptLowerPriority
    ```

### Task 2: Create `low-priority` PriorityClass
* **Requirement**: PriorityClass named `low-priority`, value `10`, `preemptionPolicy: Never`.
* **Status**: **Passed (100%)**
* **Verification**:
  - Configured correctly in [low-priority.yaml](file:///home/router/Documents/CKA/CKA-Certified-Kubernetes-Administrator/exercises/22-priorityclass/low-priority.yaml).
  - Deployed configuration on the cluster:
    ```bash
    $ kubectl get priorityclass low-priority
    NAME           VALUE   GLOBAL-DEFAULT   AGE    PREEMPTIONPOLICY
    low-priority   10      false            8m     Never
    ```

### Task 3: Create `critical-app` Pod
* **Requirement**: Pod named `critical-app` using `nginx:1.28` and assigned to `high-priority` class.
* **Status**: **Passed (100%)**
* **Verification**:
  - Specified correctly in [critical-app.yaml](file:///home/router/Documents/CKA/CKA-Certified-Kubernetes-Administrator/exercises/22-priorityclass/critical-app.yaml).
  - Running and scheduled in namespace `exercise-22`:
    ```yaml
    priorityClassName: high-priority
    priority: 1000
    ```

### Task 4: Create `background-job` Pod
* **Requirement**: Pod named `background-job` using `busybox:1.37` to run `sleep 3600` and assigned to `low-priority` class.
* **Status**: **Passed (100%)**
* **Verification**:
  - Specified correctly in [background-app.yaml](file:///home/router/Documents/CKA/CKA-Certified-Kubernetes-Administrator/exercises/22-priorityclass/background-app.yaml).
  - Running and scheduled in namespace `exercise-22`:
    ```yaml
    priorityClassName: low-priority
    priority: 10
    ```

### Task 5: Verify both pods are running and check priority values
* **Requirement**: Pods are running, check specs for `priority` and `priorityClassName`.
* **Status**: **Passed (100%)**
* **Verification**:
  - Verified they are both `Running` status on the worker node.
  - Checked priorities via custom columns:
    ```bash
    $ kubectl get pods -n exercise-22 -o custom-columns=NAME:.metadata.name,CLASS:.spec.priorityClassName,PRIORITY:.spec.priority
    NAME             CLASS           PRIORITY
    background-job   low-priority    10
    critical-app     high-priority   1000
    ```

---

## 💡 Key Takeaways for the CKA Exam

1. **Non-namespaced Scope**: `PriorityClass` is a **cluster-scoped** resource. Do not put `namespace` in the metadata of a PriorityClass.
2. **Preemption Policy**:
   - `PreemptLowerPriority` (default): Can evict lower-priority pods.
   - `Never`: Will not evict lower-priority pods. The pod stays `Pending` until resources become available naturally.
3. **Global Default**: Setting `globalDefault: true` would apply that priority to all pods without an explicit class. Only one PriorityClass in the cluster can have this set to true.
4. **Resolution during scheduling**: Pod priority only affects pods waiting to be scheduled. A higher-priority pod can preempt running lower-priority pods only if the node is out of resources, and the scheduling policy allows it.
