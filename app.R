library(shiny)
source("minCHAT_check.R")

# Define UI for data upload app ----
ui <- fluidPage(
  
  # App title ----
  titlePanel("ACLEW Annotation Scheme: minCHAT error spotter"),
  
  # Sidebar layout with input and output definitions ----
  sidebarLayout(
    
    # Sidebar panel for inputs ----
    sidebarPanel(
      h4("File upload"),
      # Input: Annotation file ----
      fileInput("file1", "Choose your eaf file",
                accept = ".eaf", 
                placeholder = "No file selected"),
      
      # Input: Follow standard AAS?
      radioButtons(inputId = "standard_AAS",
                   choices = list("yes" = 1, "no" = 0),
                   label = "Are you following the ACLEW Annotation Scheme (AAS) exactly?"),

      conditionalPanel(
        condition = "input.standard_AAS == 0",
        br(),
        br(),
        h4("Non-AAS customizations"),
        
        # Optional input: Add tier names list ----
        fileInput("tier_names", "Add new legal tier names?",
                  accept = ".csv", 
                  placeholder =  "No file selected"),
        
        # Optional input: Keep existing AAS tier names? ----
        h5(tags$b("Keep any existing AAS tier names?")),
        checkboxInput("keep_AAS_tier_names", ""),
        
        # Optional input: Remove AAS dependent tiers? ----
        checkboxGroupInput("missing_AAS_dependent_tiers",
                           "Remove expected AAS dependent tiers?",
                           choices = c("xds", "vcm", "lex", "mwu"))
      ),
      
      # Submit button:
      actionButton("submit", "Submit")
    ),
    # Main panel for displaying outputs ----
    mainPanel(
      uiOutput("report"),
      uiOutput("downloadErrors"),
      uiOutput("capitalizedwords"),
      uiOutput("hyphenatedwords")
    )
  )
)

# Define server logic to read selected file ----
server <- function(input, output) {
  
  report <- eventReactive(input$submit, {
    req(input$file1)
    req(input$standard_AAS)
    if (!is.null(input$tier_names$datapath)) {
      assign.legal.tier.names(tierfile = input$tier_names$datapath,
                              keep_AAS_tier_names = input$keep_AAS_tier_names)
    } else {
      assign.legal.tier.names()
    }
    check.annotations(input$file1$datapath, input$file1$name, input$missing_AAS_dependent_tiers)
  })
  
  output$report <- renderUI({
    req(report())
    
    tagList(
      tags$br(),
      renderText(paste0("Number of potential errors detected: ",
                        as.character(report()$n.a.alerts))),
      renderText("(downloadable list below)"),
      tags$br(),
      renderText(paste0("Number of capitalized word types detected: ",
                        as.character(report()$n.capitals))),
      renderTable(report()$capitals),
      tags$br(),
      renderText(paste0("Number of hyphenated word types detected: ",
                        as.character(report()$n.hyphens))),
      renderTable(report()$hyphens),
      tags$br()
    )
  })
  
  output$downloadErrors <- renderUI({
    # Output file name
    time.now <- gsub('-|:', '', as.character(Sys.time()))
    time.now <- gsub(' ', '_', time.now)
    
    errors <- report()$alert.table
    
    output$downloadErrorsHandler <- downloadHandler(
      filename = paste0("minCHATerrorcheck-",time.now,"-possible_errors.csv"),
      content = function(file) {
        write_csv(errors, file)
      },
      contentType = "text/csv"
    )
    
    downloadButton("downloadErrorsHandler", "Errors detected? Download a list of suspected issues here.")
  })
}

# Create Shiny app ----
shinyApp(ui, server)
