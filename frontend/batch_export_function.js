// Função para exportar múltiplas queries como PowerPoint com imagens
// Versão 7: Correção do seletor da capa (.cover-page) e Clone & Capture
const exportMultipleQueriesPPT = async () => {
    if (selectedQueriesForExport.size === 0) {
        alert('Selecione pelo menos uma query para exportar')
        return
    }

    try {
        const queryIds = Array.from(selectedQueriesForExport)
        console.time('Batch Export Total')
        console.log('Iniciando batch export com Clone & Capture:', queryIds)
        alert(`Processando Capa + ${queryIds.length} queries. Isso pode levar alguns minutos...`)

        const html2canvas = (await import('html2canvas')).default
        const queryDataArray = []

        // --- PASSO 1: CAPTURAR A CAPA ---
        try {
            console.log('Processando Capa...')
            setLoading(false)
            setSelectedQuery('cover')
            setTableData(null)

            // Aguardar renderização da capa
            let coverElement = null
            let attempts = 0
            while (attempts < 20) {
                await new Promise(resolve => setTimeout(resolve, 500))
                // CORREÇÃO: Usar .cover-page em vez de .cover-container
                coverElement = document.querySelector('.cover-page')
                if (coverElement) break
                attempts++
            }

            if (coverElement) {
                await new Promise(resolve => setTimeout(resolve, 500))
                const canvas = await html2canvas(coverElement, {
                    scale: 2,
                    backgroundColor: '#ffffff', // Capa é branca
                    logging: false,
                    useCORS: true,
                    windowWidth: 1600, // Forçar largura para evitar cortes em telas pequenas
                    windowHeight: 1200
                })
                const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/png'))
                queryDataArray.push({
                    query_id: 'cover',
                    query_title: 'Capa',
                    image_blob: blob,
                    is_cover: true
                })
                console.log('Capa capturada com sucesso')
            } else {
                console.warn('Elemento .cover-page não encontrado')
            }
        } catch (err) {
            console.error('Erro ao capturar capa:', err)
        }

        // --- PASSO 2: PROCESSAR QUERIES ---
        for (let idx = 0; idx < queryIds.length; idx++) {
            const queryId = queryIds[idx]

            try {
                setLoading(true)
                setTableData(null)
                console.log(`[${idx + 1}/${queryIds.length}] Processando query: ${queryId}`)
                console.time(`Query ${queryId}`)

                const queryResponse = await axios.post(
                    `${API_URL}/api/queries/${queryId}/execute`,
                    {},
                    { withCredentials: true, timeout: 600000 }
                )

                const data = queryResponse.data

                const previousQuery = selectedQuery
                const previousData = tableData
                setSelectedQuery(queryId)
                setLoading(false)
                setTableData(data)

                // Polling
                let tableElement = null
                let attempts = 0
                const maxAttempts = 1200

                while (attempts < maxAttempts) {
                    await new Promise(resolve => setTimeout(resolve, 500))
                    tableElement = document.querySelector('.data-table-container')
                    if (tableElement && tableElement.querySelector('table')) break
                    attempts++
                }

                if (!tableElement || !tableElement.querySelector('table')) {
                    console.warn(`Tabela não encontrada para ${queryId}`)
                    continue
                }

                await new Promise(resolve => setTimeout(resolve, 1000)) // Pausa maior para garantir render

                // --- CLONE & CAPTURE STRATEGY ---
                // Clonar a tabela para fora do container com overflow
                const originalTable = tableElement.querySelector('table')
                const cloneContainer = document.createElement('div')

                // Estilos para garantir que o clone seja renderizado completo
                cloneContainer.style.position = 'fixed'
                cloneContainer.style.top = '-10000px' // Fora da tela visível
                cloneContainer.style.left = '0'
                cloneContainer.style.width = 'fit-content' // Largura total do conteúdo
                cloneContainer.style.height = 'auto'
                cloneContainer.style.zIndex = '-1'
                cloneContainer.style.background = 'white'
                cloneContainer.style.padding = '20px' // Margem interna

                // Clonar a tabela
                const tableClone = originalTable.cloneNode(true)
                cloneContainer.appendChild(tableClone)
                document.body.appendChild(cloneContainer)

                // Capturar o clone
                const canvas = await html2canvas(cloneContainer, {
                    scale: 2,
                    backgroundColor: '#ffffff',
                    logging: false,
                    windowWidth: cloneContainer.scrollWidth + 100, // Garantir largura total
                    windowHeight: cloneContainer.scrollHeight + 100
                })

                // Remover clone
                document.body.removeChild(cloneContainer)

                const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/png'))

                queryDataArray.push({
                    query_id: queryId,
                    query_title: data.title,
                    image_blob: blob,
                    is_cover: false
                })

                console.timeEnd(`Query ${queryId}`)

                setTableData(null)
                await new Promise(resolve => setTimeout(resolve, 200))

            } catch (err) {
                console.error(`Erro na query ${queryId}:`, err)
            }
        }

        if (queryDataArray.length === 0) {
            alert('Nada foi processado')
            setLoading(false)
            return
        }

        setLoading(true)
        alert(`${queryDataArray.length} slides gerados. Criando PowerPoint...`)

        const formData = new FormData()
        formData.append('query_count', queryDataArray.length)

        queryDataArray.forEach((item, index) => {
            formData.append(`query_id_${index}`, item.query_id)
            formData.append(`query_title_${index}`, item.query_title)
            formData.append(`table_image_${index}`, item.image_blob, `slide_${index}.png`)
        })

        const response = await axios.post(
            `${API_URL}/api/export/pptx/batch-images`,
            formData,
            {
                responseType: 'blob',
                withCredentials: true,
                headers: { 'Content-Type': 'multipart/form-data' }
            }
        )

        const url = window.URL.createObjectURL(new Blob([response.data]))
        const link = document.createElement('a')
        link.href = url
        link.setAttribute('download', `export_batch_${new Date().getTime()}.pptx`)
        document.body.appendChild(link)
        link.click()
        link.remove()

        alert('PowerPoint gerado com sucesso!')
        console.timeEnd('Batch Export Total')
        setSelectedQueriesForExport(new Set())
        setIsExportMode(false)

    } catch (err) {
        console.error('Erro geral:', err)
        alert(`Erro: ${err.message}`)
    } finally {
        setLoading(false)
    }
}
