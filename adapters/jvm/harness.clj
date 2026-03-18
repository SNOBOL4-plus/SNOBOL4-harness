(ns SNOBOL4clojure.harness
  "snobol4ever test harness — Sprint 14+18C.

   Unified interface for running SNOBOL4 programs through any oracle or engine.

   Core function:
     (run engine src)          — run src, return outcome
     (run engine src :limit n) — run src, stop at statement n

   Outcome map (uniform across all engines):
     {:stdout \"...\"     ; captured stdout, whitespace-normalised
      :stderr \"...\"     ; captured stderr
      :exit   keyword  ; :ok | :error | :timeout | :step-limit
      :steps  n        ; &STCOUNT at termination (nil if not available)
      :vars   {...}}   ; variable snapshot at termination (nil if not available)

   Comparison:
     (triangulate src)               — run all oracles, return agreement map
     (crosscheck src engines)        — run oracles + engines, return corpus record
     (agree? outcome-a outcome-b)    — do two outcomes agree on stdout?

   Corpus:
     (save-corpus! records)
     (load-corpus)
  "
  (:require [clojure.java.shell  :as sh]
            [clojure.string      :as str]
            [SNOBOL4clojure.env  :as env]
            [SNOBOL4clojure.core :as sno])
  (:import  [java.io StringWriter]))

;; ── Engine registry ───────────────────────────────────────────────────────────

(def engines
  "Registry of known engines and their binary paths.
   Roles:
     :oracle  — ground truth (CSNOBOL4, SPITBOL, SNOBOL5)
     :target  — engine under test (JVM, dotnet)
   Crosscheck targets: :jvm and :dotnet only.
   :tiny excluded until Sprint 20 T_CAPTURE blocker resolved."
  {:csnobol4 {:bin  "/usr/local/bin/snobol4"
              :args ["-f" "-P256k" "-"]
              :type :subprocess
              :role :oracle}
   :spitbol  {:bin  "/usr/local/bin/spitbol"
              :args ["-b" "-"]
              :type :subprocess
              :role :oracle}
   :snobol5  {:bin  "/usr/local/bin/snobol5"
              :args ["-"]
              :type :subprocess
              :role :oracle}
   :jvm      {:type :in-process
              :role :target}
   :dotnet   {:bin  "dotnet"
              :args ["run" "--project" "/home/socrates/snobol4dotnet/Snobol4"]
              :type :subprocess
              :role :target}
   ;; :tiny — not yet a crosscheck target (Sprint 20 T_CAPTURE blocker)
   })

(def oracles
  "Ground-truth oracles, in priority order."
  [:csnobol4 :spitbol :snobol5])

(def targets
  "Engines under test. Tiny excluded until Sprint 20 blocker resolved."
  [:jvm :dotnet])

(def ^:dynamic *timeout-ms* 5000)

;; ── Helpers ───────────────────────────────────────────────────────────────────

(defn- normalise [s]
  (when s
    (->> (str/split-lines s)
         (map str/trimr)
         (reverse)
         (drop-while str/blank?)
         (reverse)
         (str/join "\n"))))

(defn- inject-limit [src n]
  (str "        &STLIMIT = " n "\n"
       "        &DUMP = 2\n"
       src))

(defn- parse-dump
  "Extract variable map from &DUMP=2 output.
   Handles CSNOBOL4 (^L prefix, uppercase) and SPITBOL (lowercase) formats."
  [raw]
  (let [lines (str/split-lines (or raw ""))
        start (first (keep-indexed
                       #(when (or (str/includes? %2 "\f")
                                  (re-find #"(?i)dump of" %2)) %1)
                       lines))]
    (when start
      (->> (drop start lines)
           (keep #(when-let [[_ k v] (re-find #"^([A-Za-z&][A-Za-z0-9_]*)\s*=\s*(.*)" (str/trim %))]
                    [(str/upper-case k) (str/trim v)]))
           (into {})))))

(defn- exit-keyword [code]
  (cond (nil? code)    :error
        (zero? code)   :ok
        (= 1 code)     :step-limit   ; CSNOBOL4/SPITBOL exit 1 on &STLIMIT
        :else          :error))

;; ── JVM in-process runner ─────────────────────────────────────────────────────

(defn- reset-runtime! []
  (env/GLOBALS)
  (reset! env/STNO    0)
  (reset! env/<STNO>  {})
  (reset! env/<LABL>  {})
  (reset! env/<CODE>  {})
  (reset! env/<CHANNELS> {})
  (reset! env/<OPSYN>    {}))

(defn- run-jvm [src limit]
  (reset-runtime!)
  (when limit (reset! env/&STLIMIT limit))
  (try
    (let [stdout (with-out-str
                   (try (sno/RUN (sno/CODE src))
                     (catch clojure.lang.ExceptionInfo e
                       (when-not (#{:end :step-limit}
                                  (get (ex-data e) :snobol/signal))
                         (throw e)))))]
      {:stdout (normalise stdout)
       :stderr ""
       :exit   (if (and limit (> @env/&STCOUNT limit)) :step-limit :ok)
       :steps  @env/&STCOUNT
       :vars   (env/snapshot!)})
    (catch Exception e
      {:stdout "" :stderr (.getMessage e)
       :exit :error :steps @env/&STCOUNT :vars (env/snapshot!)})
    (finally
      (reset! env/&STLIMIT 2147483647))))

;; ── Subprocess runner ─────────────────────────────────────────────────────────

(defn- run-subprocess [engine-key src limit]
  (let [{:keys [bin args]} (engines engine-key)
        src' (if limit (inject-limit src limit) src)]
    (try
      (let [r (apply sh/sh bin (concat args [:in src'
                                             :env {"PATH" "/usr/local/bin:/usr/bin:/bin"}]))]
        (let [raw    (str (:out r) (:err r))
              vars   (when limit (parse-dump raw))
              stdout (->> (str/split-lines (:out r))
                          (remove #(re-find #"(?i)dump of|^[A-Za-z&]\w*\s*=" %))
                          (str/join "\n")
                          normalise)]
          {:stdout stdout
           :stderr (normalise (:err r))
           :exit   (exit-keyword (:exit r))
           :steps  nil
           :vars   vars}))
      (catch Exception e
        {:stdout "" :stderr (.getMessage e)
         :exit :error :steps nil :vars nil}))))

;; ── Core public API ───────────────────────────────────────────────────────────

(defn run
  "Run src through engine, return uniform outcome map.
   Options:
     :limit n  — stop after n statements, capture variable dump"
  [engine src & {:keys [limit]}]
  (if (= engine :jvm)
    (run-jvm  src limit)
    (run-subprocess engine src limit)))

(defn agree?
  "Do two outcomes agree on stdout?"
  [a b]
  (= (:stdout a) (:stdout b)))

(defn triangulate
  "Run src through all oracles. Returns:
     {:ground-truth stdout
      :oracle        :csnobol4 | :spitbol | :snobol5 | :disagree | :all-error
      :outcomes      {engine-key outcome-map}}"
  [src]
  (let [outcomes (into {} (map #(vector % (run % src)) oracles))
        oks      (filter #(= :ok (:exit (val %))) outcomes)
        [first-ok & rest-ok] oks
        agree    (every? #(agree? (val first-ok) (val %)) rest-ok)]
    {:ground-truth (when first-ok (:stdout (val first-ok)))
     :oracle       (cond
                     (empty? oks)              :all-error
                     (and agree (> (count oks) 1)) :all-agree
                     agree                     (key first-ok)
                     :else                     :disagree)
     :outcomes     outcomes}))

(defn crosscheck
  "Run src through oracles (ground truth) and target engines.
   Returns corpus record with :status :pass|:fail|:timeout|:skip."
  [src & {:keys [targets] :or {targets [:jvm]}}]
  (let [tri      (triangulate src)
        gt       (:ground-truth tri)
        t-runs   (into {} (map #(vector % (run % src)) targets))
        status   (fn [outcome]
                   (case (:exit outcome)
                     (:timeout :step-limit) :timeout
                     :error                 :error
                     (if (= gt (:stdout outcome)) :pass :fail)))]
    {:src          src
     :oracle       (:oracle tri)
     :ground-truth gt
     :oracles      (:outcomes tri)
     :targets      (into {} (map #(vector % {:outcome  (t-runs %)
                                             :status   (status (t-runs %))}) targets))
     :status       (if (every? #(= :pass (:status (val %))) (:targets *1))
                     :pass :fail)}))

;; ── Corpus I/O ────────────────────────────────────────────────────────────────

(defn save-corpus! [records]
  (let [path "resources/golden-corpus.edn"]
    (clojure.java.io/make-parents path)
    (with-open [w (clojure.java.io/writer path :append true)]
      (doseq [r records]
        (.write w (pr-str r))
        (.newLine w)))
    (count records)))

(defn load-corpus []
  (let [path "resources/golden-corpus.edn"]
    (when (.exists (clojure.java.io/file path))
      (with-open [r (java.io.PushbackReader.
                      (clojure.java.io/reader path))]
        (loop [acc []]
          (let [form (try (read r false ::eof) (catch Exception _ ::eof))]
            (if (= form ::eof) acc (recur (conj acc form)))))))))
