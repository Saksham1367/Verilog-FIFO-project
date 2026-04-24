set fifo_signals [list \
    {tb_fifo.wr_clk} \
    {tb_fifo.rd_clk} \
    {tb_fifo.wr_en} \
    {tb_fifo.rd_en} \
    {tb_fifo.wr_ack} \
    {tb_fifo.rd_valid} \
    {tb_fifo.full} \
    {tb_fifo.empty} \
    {tb_fifo.almost_full} \
    {tb_fifo.almost_empty} \
    {tb_fifo.overflow} \
    {tb_fifo.underflow} \
    {tb_fifo.wr_ptr [3:0]} \
    {tb_fifo.rd_ptr [3:0]} \
    {tb_fifo.wr_count [4:0]} \
    {tb_fifo.rd_count [4:0]} \
    {tb_fifo.wr_data [15:0]} \
    {tb_fifo.rd_data [15:0]} \
]

set num_added [gtkwave::addSignalsFromList $fifo_signals]
puts "GTKWave loaded $num_added signals for FIFO review."

gtkwave::/Edit/Set_Trace_Max_Hier 0
gtkwave::/Time/Zoom/Zoom_Full
