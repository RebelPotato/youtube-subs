(use sh)
(import spork/math)
(import spork/path)
(import cmd)
(def at path/posix/join)

(def home (os/getenv "HOME"))
(def output-path (at home "output"))
(def whisper-path (at home "whisper.cpp"))

(defn ydl [url]
    ($ yt-dlp -o ,(at output-path "%(title)s.%(ext)s") 
        -N 4 
        --write-thumbnail --write-description --write-info-json --write-subs --write-auto-subs --embed-chapters
        ,url))

(defn ydl-file [url]
    (string/trim ($< yt-dlp -o ,(at output-path "%(title)s.%(ext)s") --print filename ,url)))

(defn ffmpeg-to-audio [input-path output-name]
    ($ ffmpeg -i ,input-path -ar 16000 -ac 1 -c:a pcm_s16le ,(at output-path (string output-name ".wav"))))

(defn transcribe [name]
    (def whisper-bin (at whisper-path "main"))
    (def whisper-model (at whisper-path "models" "ggml-large-v3-q5_0.bin"))
    ($ ,whisper-bin -m ,whisper-model --output-srt --print-colors ,(at output-path (string name ".wav"))))

(defn download [url]
    (ydl url)
    (ydl-file url))

(defn parse-sub
    "Parse the subtitle $name.wav.srt and returns a list of tuples, in (id time-duration text) format."
    [name]
    (def raw-list (with [f (file/open (at output-path (string name ".wav.srt")))]
        (file/read f :all)))
    (->> raw-list 
        (string/trim) 
        (string/split "\n") 
        (filter (fn [s] (not= s "")))
        (partition 3)))

(defn get-similar-group [similar? items]
    (def result @[])
    (var current @[])
    (defn long [list] (>= (length list) 2))
    (each item items
        (if (and (length current) (not (similar? item (last current))))
            (do
                (array/push result current)
                (set current @[item]))
            (array/push current item)))
    (if (length current)
        (array/push result current))
    (filter long result))

(defn lev [str1 str2]
  # create matrix of zeros
  (def len1 (+ (length str1) 1))
  (def len2 (+ (length str2) 1))
  (def mat (math/zero len1 len2))

  # number x and y indices in matrix
  (for i 0 len1
    (set ((mat i) 0) i))
  (for j 0 len2
    (set ((mat 0) j) j))

  # two for loops to compare strings letter by letter
  (for i 1 len1
    (for j 1 len2
      (if (= (string/slice str1 (- i 1) i)
             (string/slice str2 (- j 1) j))
        (set ((mat i) j) (min
                           (+ ((mat (- i 1)) j) 1)
                           (+ ((mat i) (- j 1)) 1)
                           ((mat (- i 1)) (- j 1))))
        (set ((mat i) j) (min
                           (+ ((mat (- i 1)) j) 1)
                           (+ ((mat (- i 1)) (- j 1)) 1)
                           (+ ((mat i) (- j 1)) 1))))))
  ((mat (- len1 1)) (- len2 1)))

(defn get-bad-time [name]
    (defn spt [str] (map (fn [s] ((string/split "," s) 0)) (string/split " --> " str)))
    (->> (parse-sub name) 
        (get-similar-group (fn [s1 s2] (and s2 (<= (lev (s1 2) (s2 2)) 5))))
        (map (fn [s] (array ((spt ((first s) 1)) 0) ((spt ((last s) 1)) 1))))))


(defn ffmpeg-cut [input-name startend output-name]
    ($ ffmpeg   -i ,(at output-path (string input-name ".wav"))
                -ss ,(startend 0)
                -to ,(startend 1)
                -c copy ,(at output-path (string output-name ".wav"))))

(defn transcribe-fix []
    # assume that output0.wav already exists:
    # (transcribe "output0")
    (var i 0)
    (var j 0)
    (defn out [x] (string "output" x))

    (def ini (get-bad-time "output0"))
    (var errors @{0 ini})

    (while (<= i j)
        (def times (errors i))
        (each time times
            (set j (inc j))
            (printf "Fixing %s [%s --> %s] to %s" (out i) (time 0) (time 1) (out j))
            (ffmpeg-cut (out i) time (out j))
            (transcribe (out j))
            (set (errors j) (get-bad-time (out j))))
        (set i (inc i)))
    (print "Done."))

(defn download-transcribe [url]
    (ffmpeg-to-audio (download url) "output0")
    (transcribe "output0")
    (transcribe-fix))

(cmd/def "Downloads videos from youtube, then uses whisper.cpp to transcribe them, and fixes the transcription errors."
    url (required ["URL" :string])
)

(download-transcribe url)

# (get-bad-time "output0")