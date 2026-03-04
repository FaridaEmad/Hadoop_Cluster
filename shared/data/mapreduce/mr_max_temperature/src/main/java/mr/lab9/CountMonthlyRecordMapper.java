package mr.lab9;

import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.DoubleWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import java.io.IOException;
import org.apache.hadoop.mapreduce.Mapper;

public class CountMonthlyRecordMapper {
	public static void main(String[] args) throws Exception {
		if (args.length != 2) {
			System.err.println("Usage: CountMonthlyRecordMapper <input path> <output path>");
			System.exit(-1);
		}

		// Job configurations
		Job job = new Job();
		job.setJarByClass(CountMonthlyRecordMapper.class);
		job.setJobName("Count Monthly Record");
		job.setNumReduceTasks(0);
		job.setMapperClass(CountMapper.class);
		job.setOutputKeyClass(Text.class);
		job.setOutputValueClass(DoubleWritable.class);

		// Input & Output
		FileInputFormat.addInputPath(job, new Path(args[0]));
		FileOutputFormat.setOutputPath(job, new Path(args[1]));

		// Run Job
		System.exit(job.waitForCompletion(true) ? 0 : 1);
	}
}

class CountMapper extends Mapper<LongWritable, Text, Text, DoubleWritable> {
	@Override
	public void map(LongWritable key, Text value, Context context) throws IOException, InterruptedException {
		// get value
		String line = value.toString();

		// Ignore headers
		if (line.startsWith("STATION")) { return; }
		
		// Parse fields
		String[] fields = line.split("\\|");
		String month = fields[2].substring(5, 7);

		context.write(new Text(month), new DoubleWritable(1));
	}
}
