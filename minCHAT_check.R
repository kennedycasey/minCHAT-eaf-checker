library(tidyverse)
library(lubridate)
library(stringr)
library(phonfieldwork)

assign.legal.tier.names <-
  function(tierfile = NA,
           keep_AAS_tier_names = FALSE) {
    aclew.tier.names <-
      "(^xds@[FMU][ACU](\\d{1}|E)$)|(^xds@EE1$)|(^(vcm|lex|mwu)@CHI$)|(^[FMU][ACU](\\d{1}|E)$)|(^EE1$)|(^CHI$)|(^context$)|(^code_num$)|(^code$)|(^notes$)|(^on_off)"
    if (is.na(tierfile)) {
      legal.tier.names <- aclew.tier.names
    } else {
      legal.tier.names <- read_csv(tierfile)
      
      legal.tier.names <- legal.tier.names %>%
        mutate(tier_name = paste0(tier_name, collapse = "|")) %>%
        distinct() %>%
        pull(1)
      
      if (keep_AAS_tier_names == TRUE) {
        legal.tier.names <- paste0(aclew.tier.names, "|", legal.tier.names)
      }
    }
    legal.tier.names <<- legal.tier.names
  }

check.annotations <- function(annfile, nameannfile, rmtiers) {
  alert.table <- tibble(
    filename = character(),
    alert = character(),
    onset = integer(),
    offset = integer(),
    tier = character(),
    value = character()
  )
  
  convert_ms_to_hhmmssms <- function(msectime) {
    if (is.na(msectime)) {
      return("none")
    } else {
      ms_p_hr <- 60 * 60 * 1000
      ms_p_mn <- 60 * 1000
      ms_p_sc <- 1000
      hh <- floor(msectime / ms_p_hr)
      if (hh < 10) {
        hh <- paste0("0", hh)
      }
      msectime <- msectime %% ms_p_hr
      mm <- floor(msectime / ms_p_mn)
      if (mm < 10) {
        mm <- paste0("0", mm)
      }
      msectime <- msectime %% ms_p_mn
      ss <- floor(msectime / ms_p_sc)
      if (ss < 10) {
        ss <- paste0("0", ss)
      }
      msectime <- msectime %% ms_p_sc
      msec <- msectime
      if (msec < 100) {
        msec <- paste0(msec, "0")
      }
      newtime <- paste0(hh, ":", mm, ":", ss, ".", msec)
      return(newtime)
    }
  }
  
  add_alert <-
    function (filename,
              alert,
              onset,
              offset,
              tier,
              value) {
      bind_rows(
        alert.table,
        tibble(
          filename = filename,
          alert = alert,
          onset = onset,
          offset = offset,
          tier = tier,
          value = value
        )
      )
    }
  
  check_minCHATspclchr <- function(utt, minCHATspclchr) {
    if (minCHATspclchr == "squarebraces") {
      utterance <-
        str_replace_all(utt, "(\\[- [[:alnum:]]{3}\\])", "_lg_") %>%
        str_replace_all("(\\[: [[:alnum:] ,.!?_'@:-]+\\])|(\\[=! [[:alnum:]]+\\])",
                        "_bb_") %>%
        str_replace_all("<[[:alnum:] ,.!?_'@&=:-]+> _bb_", "_aa_")
      # and now in case of <<xxx> [xxx]> [xxx] double embeddings...
      embedded.braces.pattern <-
        "<[[:alnum:] ,.!?_'@&=:-]*_aa_[[:alnum:] ,.!?-_'@&=]*> _bb_"
      if (str_detect(utterance, embedded.braces.pattern)) {
        utterance <- str_replace_all(utterance, embedded.braces.pattern, "")
      }
      utterance <- str_replace_all(utterance, "(_aa_)|(^_lg_)", "")
      if (grepl("([][<>])|(_bb_)|(_aa_)|(_lg_)", utterance)) {
        return("incorrect use of square braces")
      } else {
        return("okay")
      }
    } else if (minCHATspclchr == "atsign") {
      utterance <- str_replace_all(utt,
                                   "[[:alnum:]]+@s\\:[a-z]{3}]",
                                   "atat]") %>%
        str_replace_all("[[:alnum:]]+@s\\:[a-z]{3}>",
                        "atat>") %>%
        str_replace_all("([[:alnum:]]+@s\\:[a-z]{3}[ ,.!?-])|([[:alnum:]]+@[lc])",
                        "atat")
      if (grepl("@", utterance)) {
        return("incorrect use of @ sign")
      } else {
        return("okay")
      }
    } else if (minCHATspclchr == "ampersand") {
      utterance <- str_replace_all(utt,
                                   "(&=[[:alnum:]]+)|(&[[:alnum:]_'@-]+)|([[:alnum:]_'@-]+&)",
                                   "mpmp")
      if (grepl("&", utterance)) {
        return("incorrect use of & sign")
      } else {
        return("okay")
      }
    } else {
      return("ERROR: contact app developer")
    }
  }
  
  annots <- eaf_to_df(annfile) %>%
    transmute(
      tier = tier_name,
      speaker = ifelse(
        str_detect(tier, "xds|vcm|lex|mwu"),
        substr(tier, nchar(tier) - 2, nchar(tier)),
        ifelse(nchar(tier) == 3, tier, "")
      ),
      onset = time_start * 1000,
      offset = time_end * 1000,
      duration = offset - onset,
      value = content
    )
  filename <- unlist((strsplit(nameannfile, "\\.eaf")))[1]
  
  ##---- CHECKS ----##
  
  #-- correct tier names --#
  bad.format.tier.names <- unique(annots$tier[which(!grepl(legal.tier.names, annots$tier))])
  if (length(bad.format.tier.names) > 0) {
    alert.table <- add_alert(
      filename,
      paste0(
        "wrong format tier name(s): ",
        paste(bad.format.tier.names, collapse = ", ")
      ),
      min(annots$onset),
      max(annots$offset),
      "",
      ""
    )
  }
  # if the pre- or post-fixes don't match one of the limited types
  
  tier.names <-
    unique(unlist(strsplit(annots$tier[which(grepl("@", annots$tier))], "@")))
  name.part.matches <-
    tier.names %in% c("vcm", "lex", "mwu", "xds") |
    grepl("([FMU][ACU](\\d{1}|E))|(EE1)", tier.names) |
    grepl("^CHI$", tier.names)
  if (FALSE %in% name.part.matches) {
    alert.table <- add_alert(
      filename,
      paste0(
        "illegal tier prefix(es) or speaker name(s) (may overlap with wrong format): ",
        paste(unique(tier.names[which(name.part.matches == FALSE)]),
              collapse = " ")
      ),
      min(annots$onset),
      max(annots$offset),
      "",
      ""
    )
  }
  
  #-- missing contingent annotations --#
  n.CHI <- filter(annots, tier == "CHI") %>% nrow()
  # if there are CHI vocalizations...
  if (n.CHI > 0) {
    # if there's a VCM tier, make sure there are the same
    # number of annotations as there are in the CHI tier
    if (TRUE %in% grepl("vcm", annots$tier)) {
      if (filter(annots, tier == "vcm@CHI") %>% nrow() != n.CHI) {
        alert.table <- add_alert(
          filename,
          "incorrect number of VCM annotations",
          min(annots$onset),
          max(annots$offset),
          "",
          ""
        )
      }
      n_cb <- filter(annots, tier == "vcm@CHI" &
                       value == "C") %>% nrow()
      n_lx <- filter(annots, tier == "lex@CHI" &
                       value == "W") %>% nrow()
      n_mw <- filter(annots, tier == "mwu@CHI" &
                       value == "M") %>% nrow()
      # if the child produced canonical babbles...
      if (n_cb > 0) {
        # check if there is a matching number of LEX codes
        # for each canonincal babble
        if (n_cb == nrow(filter(annots, tier == "lex@CHI"))) {
          # if so, check if there is a matching number of MWU codes
          # for each babble with words
          if (n_lx != nrow(filter(annots, tier == "mwu@CHI"))) {
            alert.table <- add_alert(
              filename,
              "incorrect number of MWU annotations; should be equal to number of LEX = 'W'",
              min(annots$onset),
              max(annots$offset),
              "",
              ""
            )
          }
        } else {
          alert.table <- add_alert(
            filename,
            "incorrect number of LEX annotations; should be equal to number of VCM = 'C'; re-check MWU too, if relevant",
            min(annots$onset),
            max(annots$offset),
            "",
            ""
          )
        }
      } else {
        # if the child produced no canonical babbles but there are
        # LEX and MWU annots send an alert
        if (nrow(filter(annots, tier == "lex@CHI")) > 0 ||
            nrow(filter(annots, tier == "mwu@CHI")) > 0) {
          alert.table <- add_alert(
            filename,
            "too many LEX/MWU annotations because there are no cases of VCM = 'C'",
            min(annots$onset),
            max(annots$offset),
            "",
            ""
          )
        }
      }
    } else {
      # if there's no VCM tier, make sure instead that there
      # are the same number of annotations on LEX as there are
      # in the CHI tier
      if (TRUE %in% grepl("lex", annots$tier)) {
        n_lx <- filter(annots, tier == "lex@CHI" &
                         value == "W") %>% nrow()
        n_mw <- filter(annots, tier == "mwu@CHI" &
                         value == "M") %>% nrow()
        # if the child produced lexical words...
        if (n_lx > 0) {
          # check if there is a matching number of MWU codes
          # for each babble with words
          if (n_lx != nrow(filter(annots, tier == "mwu@CHI"))) {
            alert.table <- add_alert(
              filename,
              "incorrect number of MWU annotations; should be equal to number of LEX = 'W'",
              min(annots$onset),
              max(annots$offset),
              "",
              ""
            )
          }
        } else {
          # if the child produced no lexical utterances but there are
          # MWU annots send an alert
          if (nrow(filter(annots, tier == "mwu@CHI")) > 0) {
            alert.table <- add_alert(
              filename,
              "too many MWU annotations because there are no cases of LEX = 'W'",
              min(annots$onset),
              max(annots$offset),
              "",
              ""
            )
          }
        }
      } else {
        if (!("vcm" %in% rmtiers & "lex" %in% rmtiers)) {
          alert.table <- add_alert(
            filename,
            "missing LEX or VCM tier",
            min(annots$onset),
            max(annots$offset),
            "",
            ""
          )
        }
      }
    }
  }
  # check whether there are the same number of xds annotations as
  # non-CHI vocalizations
  nonCHI.vocs <- annots %>%
    filter(grepl("(^[A-Z]{2}\\d{1}$)|(^xds@[A-Z]{2}\\d{1}$)", tier)) %>%
    group_by(tier, speaker) %>%
    summarize(nvocs = n()) %>%
    ungroup() %>%
    mutate(tier = case_when(grepl("^xds@", tier) ~ "xds.vocs",
                            TRUE ~ "spkr.vocs"))
  if (nrow(nonCHI.vocs) > 0) {
    if (nrow(filter(nonCHI.vocs, tier == "xds.vocs")) > 0) {
      nonCHI.vocs <- nonCHI.vocs %>%
        group_by(speaker) %>%
        spread(tier, nvocs, drop = FALSE) %>%
        mutate(match = spkr.vocs == xds.vocs) %>%
        filter(match == FALSE) %>%
        pull(speaker)
    }
  } else {
    nonCHI.vocs <- c()
  }
  if (length(nonCHI.vocs) > 0 & !("xds" %in% rmtiers)) {
    nonCHI.vocs.str <- paste0(nonCHI.vocs, collapse = ", ")
    alert.xds <- paste0(
      "missing XDS annotations; compare the # of utterances with the # of XDS annotations for ",
      nonCHI.vocs.str
    )
    alert.table <- add_alert(filename,
                             alert.xds,
                             min(annots$onset),
                             max(annots$offset),
                             "",
                             "")
  }
  
  #-- invalid annotation values: closed vocabulary --#
  
  if (!("xds" %in% rmtiers)) {
    xds.vals <- filter(annots, grepl("xds@", tier)) %>%
      select(value, onset, offset, tier) %>%
      mutate(
        filename = filename,
        alert =
          "illegal XDS annotation value",
        legal = case_when(
          value == "T" ~ "okay",
          value == "C" ~ "okay",
          value == "B" ~ "okay",
          value == "A" ~ "okay",
          value == "U" ~ "okay",
          value == "P" ~ "okay",
          value == "O" ~ "okay",
          TRUE ~ "problem"
        )
      ) %>%
      filter(legal != "okay") %>%
      select(filename, alert, onset, offset, tier, value)
  }
  
  if (!("vcm" %in% rmtiers)) {
    vcm.vals <- filter(annots, grepl("vcm@", tier)) %>%
      select(value, onset, offset, tier) %>%
      mutate(
        filename = filename,
        alert =
          "illegal VCM annotation value",
        legal = case_when(
          value == "C" ~ "okay",
          value == "N" ~ "okay",
          value == "Y" ~ "okay",
          value == "L" ~ "okay",
          value == "U" ~ "okay",
          TRUE ~ "problem"
        )
      ) %>%
      filter(legal != "okay") %>%
      select(filename, alert, onset, offset, tier, value)
  }
  
  if (!("lex" %in% rmtiers)) {
    lex.vals <- filter(annots, grepl("lex@", tier)) %>%
      select(value, onset, offset, tier) %>%
      mutate(
        filename = filename,
        alert =
          "illegal LEX annotation value",
        legal = case_when(value == "W" ~ "okay",
                          value == "0" ~ "okay",
                          TRUE ~ "problem")
      ) %>%
      filter(legal != "okay") %>%
      select(filename, alert, onset, offset, tier, value)
  }
  
  if (!("mwu" %in% rmtiers)) {
    mwu.vals <- filter(annots, grepl("mwu@", tier)) %>%
      select(value, onset, offset, tier) %>%
      mutate(
        filename = filename,
        alert =
          "illegal MWU annotation value",
        legal = case_when(value == "M" ~ "okay",
                          value == "1" ~ "okay",
                          TRUE ~ "problem")
      ) %>%
      filter(legal != "okay") %>%
      select(filename, alert, onset, offset, tier, value)
  }
  
  # add closed vocabulary alerts to table
  
  if (length(rmtiers) > 0) {
    if (!("xds") %in% rmtiers) {
      alert.table <- bind_rows(alert.table,
                               xds.vals)
    }
    
    if (!("vcm") %in% rmtiers) {
      alert.table <- bind_rows(alert.table,
                               vcm.vals)
    }
    
    if (!("lex") %in% rmtiers) {
      alert.table <- bind_rows(alert.table,
                               lex.vals)
    }
    
    if (!("mwu") %in% rmtiers) {
      alert.table <- bind_rows(alert.table,
                               mwu.vals)
    }
  }
  
  #-- invalid annotation values: transcription --#
  # note that the regular expressions below are *far* from airtight
  # and improvements would be most welcome
  utts <- filter(annots, tier == speaker)
  # check for utterances without transcription
  empty.utts <- filter(utts,
                       (grepl("^[\\s[[:punct:]]]*$", value) | is.na(value))) %>%
    select(onset, offset, tier, value) %>%
    mutate(filename = filename,
           alert = "empty transcription") %>%
    select(filename, alert, onset, offset, tier, value)
  # check for the presence of a single terminal mark at the end
  nonterminating.utts <-
    filter(utts, !grepl("[.!?]{1}$", value)) %>%
    select(onset, offset, tier, value) %>%
    mutate(filename = filename,
           alert = "no utterance terminator") %>%
    select(filename, alert, onset, offset, tier, value)
  # check for the presence of multiple terminal marks in the utterance
  utts.nopausessqbrackets <- str_replace_all(utts$value, " \\(\\.*\\)", "") %>%
    str_replace_all("\\[.*?\\]", "")
  utts$value.mod <- utts.nopausessqbrackets
  overterminating.utts <- utts %>%
    mutate(
      n_terms = str_count(value.mod, "[.!?]"),
      filename = filename,
      alert = "2+ utterance terminators"
    ) %>%
    filter(n_terms > 1) %>%
    select(filename, alert, onset, offset, tier, value)
  # check for utterances with extra spaces
  extspace.utts <- filter(utts,
                       (grepl("\\s{2,}|^\\s|\\s[[:punct:]]$|[[:punct:]]\\s$", value))) %>%
    select(onset, offset, tier, value) %>%
    mutate(filename = filename,
           alert = "extra space(s)") %>%
    select(filename, alert, onset, offset, tier, value)
  # check for uses of square bracket expressions
  squarebrace.errs <- filter(utts, grepl("[[]", value)) %>%
    select(onset, offset, tier, value)
  if (nrow(squarebrace.errs) > 0) {
    squarebrace.errs <- squarebrace.errs %>%
      rowwise() %>%
      mutate(alert.sq = check_minCHATspclchr(value, "squarebraces")) %>%
      filter(alert.sq != "okay")
  }
  # check for uses of @
  atsign.errs <- filter(utts, grepl("@", value)) %>%
    select(onset, offset, tier, value)
  if (nrow(atsign.errs) > 0) {
    atsign.errs <- atsign.errs %>%
      rowwise() %>%
      mutate(alert.at = check_minCHATspclchr(value, "atsign")) %>%
      filter(alert.at != "okay")
  }
  # check for uses of &
  ampsnd.errs <- filter(utts, grepl("&", value)) %>%
    select(onset, offset, tier, value)
  if (nrow(ampsnd.errs) > 0) {
    ampsnd.errs <- ampsnd.errs %>%
      rowwise() %>%
      mutate(alert.am = check_minCHATspclchr(value, "ampersand")) %>%
      filter(alert.am != "okay")
  }
  spchchr.errs <- full_join(squarebrace.errs, atsign.errs) %>%
    full_join(ampsnd.errs)
  if (nrow(spchchr.errs) > 0) {
    if (!("alert.sq" %in% colnames(spchchr.errs))) {
      spchchr.errs <- spchchr.errs %>%
        mutate(alert.sq = NA)
    }
    if (!("alert.at" %in% colnames(spchchr.errs))) {
      spchchr.errs <- spchchr.errs %>%
        mutate(alert.at = NA)
    }
    if (!("alert.am" %in% colnames(spchchr.errs))) {
      spchchr.errs <- spchchr.errs %>%
        mutate(alert.am = NA)
    }
    spchchr.errs <- spchchr.errs %>%
      mutate(filename = filename,
             alert = paste(alert.sq, alert.at, alert.am, sep = ", ")) %>%
      select(filename, alert, onset, offset, tier, value) %>%
      mutate(alert = str_replace_all(alert, ", NA", ""))
  }
  
  # add open transcription alerts to table
  alert.table <- bind_rows(alert.table,
                           empty.utts,
                           extspace.utts,
                           nonterminating.utts,
                           overterminating.utts,
                           spchchr.errs)
  
  # List capitalized words found
  no.na.utts <- filter(utts, !is.na(value))
  all.utts.together <- paste0(" ", no.na.utts$value, collapse = " ")
  capitalwords.used <- tibble(`capitalized words` = sort(unique(unlist(
    regmatches(
      all.utts.together,
      gregexpr(" [A-Z][A-Za-z@_]*",
               all.utts.together)
    )
  )))) %>%
    mutate(`capitalized words` = trimws(`capitalized words`))
  
  # List of hyphenated words found
  hyphenwords.used <- tibble(`hyphenated words` = sort(unique(unlist(
    regmatches(
      all.utts.together,
      gregexpr("[A-Za-z]+-[A-Za-z]+",
               all.utts.together)
    )
  )))) %>%
    mutate(`hyphenated words` = trimws(`hyphenated words`))
  
  # convert msec times to HHMMSS and return assessment
  if (nrow(alert.table) > 0) {
    alert.table <- alert.table %>%
      rowwise() %>%
      mutate(start = convert_ms_to_hhmmssms(onset),
             stop = convert_ms_to_hhmmssms(offset)) %>%
      select(filename, alert, tier, value, start, stop)
    
    return(
      list(
        alert.table = alert.table,
        n.a.alerts = nrow(alert.table),
        capitals = capitalwords.used,
        n.capitals = nrow(capitalwords.used),
        hyphens = hyphenwords.used,
        n.hyphens = nrow(hyphenwords.used)
      )
    )
  } else {
    alert.table.NA = tibble(filename = filename,
                            alerts = "No errors detected! :D")
    return(
      list(
        alert.table = alert.table.NA,
        n.a.alerts = 0,
        capitals = capitalwords.used,
        n.capitals = nrow(capitalwords.used),
        hyphens = hyphenwords.used,
        n.hyphens = nrow(hyphenwords.used)
      )
    )
  }
}
